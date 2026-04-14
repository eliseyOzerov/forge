//
//  Lift.swift
//  ForgeSwift
//
//  Lifts a child into a top-level overlay while keeping its slot in
//  the layout. The slot stays sized, stateful, and hit-testable so
//  gestures started on it keep firing across the lift; the overlay
//  copy is purely visual and tracks the slot's screen rect.
//
//  Useful for:
//    - Context menu previews (scaled/animated preview above content)
//    - Drag-out-of-stack effects
//    - Hero-like transitions between slot and overlay
//    - Any "promote this view above siblings" moment
//
//  ```swift
//  let controller = LiftController()
//  Lift(controller: controller) { lift in
//      Button(action: { lift.set(!lift.value) }) {
//          Text(lift.value ? "Lifted" : "Lift me")
//      }
//  }
//  ```
//
//  The builder is invoked twice while lifted (once for the slot, once
//  for the overlay), so any state created *inside* the builder will be
//  duplicated. Hoist stateful content above Lift.
//

#if canImport(UIKit)
import UIKit

// MARK: - LiftController

/// Canonical lifted-state holder + listener registry. Callers pass a
/// LiftController into Lift to control the lift externally, or let Lift
/// create its own. Set via `controller.set(true/false)`; observers fire
/// synchronously on the main actor.
@MainActor public final class LiftController {
    public private(set) var value: Bool

    private var listeners: [UUID: (Bool) -> Void] = [:]

    public init(_ initial: Bool = false) {
        self.value = initial
    }

    public func set(_ newValue: Bool) {
        guard value != newValue else { return }
        value = newValue
        for listener in listeners.values { listener(newValue) }
    }

    public func toggle() { set(!value) }

    @discardableResult
    func observe(_ handler: @escaping (Bool) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = handler
        return id
    }

    func unobserve(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }
}

/// The builder receives a `LiftView` that reads the *visible* lift
/// state for the current build (always false for the slot; the overlay's
/// visible value for the overlay), and writes go to the canonical
/// controller. This mirrors Wave's forwarding / overlay-bridge notifiers.
@MainActor public struct LiftView {
    public let value: Bool
    private let canonical: LiftController

    init(value: Bool, canonical: LiftController) {
        self.value = value
        self.canonical = canonical
    }

    public func set(_ v: Bool) { canonical.set(v) }
    public func toggle() { canonical.set(!canonical.value) }
}

// MARK: - Lift

public struct Lift: LeafView {
    public let controller: LiftController?
    public let dismissDuration: TimeInterval
    public let builder: @MainActor (LiftView) -> any View

    public init(
        controller: LiftController? = nil,
        dismissDuration: TimeInterval = 0,
        @ChildBuilder builder: @escaping @MainActor (LiftView) -> any View
    ) {
        self.controller = controller
        self.dismissDuration = dismissDuration
        self.builder = builder
    }

    public func makeRenderer() -> Renderer {
        LiftRenderer(controller: controller, dismissDuration: dismissDuration, builder: builder)
    }
}

final class LiftRenderer: Renderer {
    var controller: LiftController?
    var dismissDuration: TimeInterval
    var builder: @MainActor (LiftView) -> any View

    init(
        controller: LiftController?,
        dismissDuration: TimeInterval,
        builder: @escaping @MainActor (LiftView) -> any View
    ) {
        self.controller = controller
        self.dismissDuration = dismissDuration
        self.builder = builder
    }

    func mount() -> PlatformView {
        let v = LiftHostView()
        v.configure(controller: controller, dismissDuration: dismissDuration, builder: builder)
        return v
    }

    func update(_ platformView: PlatformView) {
        guard let v = platformView as? LiftHostView else { return }
        v.configure(controller: controller, dismissDuration: dismissDuration, builder: builder)
    }
}

// MARK: - LiftHostView

/// Slot view. Mounts the child subtree in its own bounds for the slot
/// build; on lift, mounts a second subtree on the window sized + framed
/// to the slot's current screen rect.
final class LiftHostView: UIView {
    private var canonical: LiftController?
    private var ownsController = false
    private var dismissDuration: TimeInterval = 0
    private var builder: (@MainActor (LiftView) -> any View)?

    /// Visible state for the overlay copy. Lags the canonical value by
    /// one frame on insertion (so effects see a false→true change and
    /// animate in), and leads it on dismissal (false first, then tear-
    /// down after dismissDuration).
    private var overlayVisible: Bool = false

    /// Whether the overlay is currently mounted (distinct from canonical
    /// because we keep the overlay mounted through the dismiss animation).
    private var presented: Bool = false

    private var observerID: UUID?
    private var dismissTimer: Timer?

    private var slotResolver: Resolver?
    private var slotNode: Node?

    private var overlayResolver: Resolver?
    private var overlayContainer: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Sizing

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        slotNode?.platformView?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        slotNode?.platformView?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        slotNode?.platformView?.frame = bounds
        syncOverlayFrame()
    }

    // MARK: Configuration

    func configure(
        controller: LiftController?,
        dismissDuration: TimeInterval,
        builder: @escaping @MainActor (LiftView) -> any View
    ) {
        self.dismissDuration = dismissDuration
        self.builder = builder

        // Bind to the controller — use external if passed, or own one.
        let external = controller ?? {
            ownsController = true
            return LiftController()
        }()

        if canonical !== external {
            // Switch to a new canonical. Detach the old observer, tear
            // down any presentation, and rebind.
            if let old = canonical, let id = observerID {
                old.unobserve(id)
            }
            teardownOverlay()
            canonical = external
            observerID = external.observe { [weak self] lifted in
                self?.handleCanonicalChange(lifted)
            }
            // If the external controller is already lifted at bind time,
            // defer presentation to the next frame so we have a window.
            if external.value {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.canonical?.value == true else { return }
                    self.show()
                }
            }
        }

        rebuildSlot()
    }

    // MARK: Slot rebuild

    private func rebuildSlot() {
        guard let builder, let canonical else { return }
        // Slot always reads `lifted == false` so any lift-conditional
        // rendering inside the builder uses the untransformed form,
        // keeping the slot's layout footprint stable.
        let lift = LiftView(value: false, canonical: canonical)
        let child = builder(lift)

        if slotResolver == nil {
            let resolver = Resolver()
            slotResolver = resolver
            let pv = resolver.mount(child)
            slotNode = resolver.rootNode
            addSubview(pv)
            pv.frame = bounds
        } else if let node = slotNode, node.canUpdate(to: child) {
            node.update(from: child)
        } else {
            // Different view type — remount.
            slotNode?.platformView?.removeFromSuperview()
            let resolver = Resolver()
            slotResolver = resolver
            let pv = resolver.mount(child)
            slotNode = resolver.rootNode
            addSubview(pv)
            pv.frame = bounds
        }

        // Slot visibility: hide (keep size) while presented. Reveal once
        // we tear down. Matches Wave's maintainSize semantics — content
        // still occupies layout, just not drawn.
        slotNode?.platformView?.isHidden = presented
    }

    // MARK: Canonical change → show/hide

    private func handleCanonicalChange(_ lifted: Bool) {
        if lifted {
            dismissTimer?.invalidate()
            dismissTimer = nil
            show()
        } else {
            // Flip overlay visible state to false so the builder's
            // in-animation runs back to rest.
            overlayVisible = false
            rebuildOverlay()

            dismissTimer?.invalidate()
            if dismissDuration <= 0 {
                hide()
            } else {
                dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDuration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.canonical?.value == false else { return }
                        self.hide()
                    }
                }
            }
        }
    }

    // MARK: Show

    private func show() {
        guard !presented, let window = self.window else { return }
        presented = true
        slotNode?.platformView?.isHidden = true

        // Mount overlay container on the window, sized + positioned at
        // the slot's current screen rect.
        let container = UIView(frame: windowRect)
        container.isUserInteractionEnabled = false  // visual only
        window.addSubview(container)
        overlayContainer = container

        // First frame: overlayVisible = false (matches slot's rest state).
        overlayVisible = false
        rebuildOverlay()

        // Next frame: flip to true so animated effects see the change.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.canonical?.value == true else { return }
            self.overlayVisible = true
            self.rebuildOverlay()
        }
    }

    // MARK: Hide

    private func hide() {
        guard presented else { return }
        presented = false
        teardownOverlay()
        slotNode?.platformView?.isHidden = false
    }

    private func teardownOverlay() {
        overlayContainer?.removeFromSuperview()
        overlayContainer = nil
        overlayResolver = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    // MARK: Overlay rebuild

    private func rebuildOverlay() {
        guard let container = overlayContainer, let builder, let canonical else { return }
        let lift = LiftView(value: overlayVisible, canonical: canonical)
        let view = builder(lift)

        if overlayResolver == nil {
            let resolver = Resolver()
            overlayResolver = resolver
            let pv = resolver.mount(view)
            pv.frame = container.bounds
            pv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(pv)
        } else if let node = overlayResolver?.rootNode, node.canUpdate(to: view) {
            node.update(from: view)
        } else {
            container.subviews.forEach { $0.removeFromSuperview() }
            let resolver = Resolver()
            overlayResolver = resolver
            let pv = resolver.mount(view)
            pv.frame = container.bounds
            pv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(pv)
        }
    }

    // MARK: Overlay positioning

    private var windowRect: CGRect {
        guard let window else { return .zero }
        return convert(bounds, to: window)
    }

    private func syncOverlayFrame() {
        overlayContainer?.frame = windowRect
    }

    // MARK: Teardown

    deinit {
        // Cleanup happens on the main actor via a cleanup hook if needed;
        // for v1 rely on removal from superview + observer's weak self.
    }
}

#endif
