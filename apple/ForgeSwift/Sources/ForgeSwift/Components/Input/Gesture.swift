// MARK: - AccessibilityTraits

public struct AccessibilityTraits: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let button     = AccessibilityTraits(rawValue: 1 << 0)
    public static let link       = AccessibilityTraits(rawValue: 1 << 1)
    public static let image      = AccessibilityTraits(rawValue: 1 << 2)
    public static let selected   = AccessibilityTraits(rawValue: 1 << 3)
    public static let adjustable = AccessibilityTraits(rawValue: 1 << 4)
    public static let header     = AccessibilityTraits(rawValue: 1 << 5)
    public static let notEnabled = AccessibilityTraits(rawValue: 1 << 6)
    public static let staticText = AccessibilityTraits(rawValue: 1 << 7)
}

// MARK: - AccessibilityConfig

public struct AccessibilityConfig {
    public var traits: AccessibilityTraits
    public var label: String?
    public var value: String?
    public var activate: (@MainActor () -> Bool)?
    public var increment: (@MainActor () -> Void)?
    public var decrement: (@MainActor () -> Void)?

    public init(
        traits: AccessibilityTraits = [],
        label: String? = nil,
        value: String? = nil,
        activate: (@MainActor () -> Bool)? = nil,
        increment: (@MainActor () -> Void)? = nil,
        decrement: (@MainActor () -> Void)? = nil
    ) {
        self.traits = traits; self.label = label; self.value = value
        self.activate = activate; self.increment = increment; self.decrement = decrement
    }
}

#if canImport(UIKit)
import UIKit

extension AccessibilityTraits {
    var uiTraits: UIAccessibilityTraits {
        var result: UIAccessibilityTraits = []
        if contains(.button)     { result.insert(.button) }
        if contains(.link)       { result.insert(.link) }
        if contains(.image)      { result.insert(.image) }
        if contains(.selected)   { result.insert(.selected) }
        if contains(.adjustable) { result.insert(.adjustable) }
        if contains(.header)     { result.insert(.header) }
        if contains(.notEnabled) { result.insert(.notEnabled) }
        if contains(.staticText) { result.insert(.staticText) }
        return result
    }
}

// MARK: - Gesture

/// A transparent wrapper that attaches gesture recognizers to its
/// platform view. The child is properly parented in the node tree,
/// and gestures coexist with child interactions (buttons, etc.)
/// through UIKit's normal gesture arbitration.
///
/// ```swift
/// Gesture(
///     drag: DragConfig(
///         onStart: { e in ... },
///         onUpdate: { e in ... },
///         onEnd: { e in ... }
///     )
/// ) {
///     MyContent()
/// }
/// ```
public struct Gesture: ProxyView {
    public let child: any View
    public let tap: TapConfig?
    public let doubleTap: DoubleTapConfig?
    public let press: PressConfig?
    public let hold: HoldConfig?
    public let drag: DragConfig?
    public let pan: PanConfig?
    public let accessibility: AccessibilityConfig?

    public init(
        tap: TapConfig? = nil,
        doubleTap: DoubleTapConfig? = nil,
        press: PressConfig? = nil,
        hold: HoldConfig? = nil,
        drag: DragConfig? = nil,
        pan: PanConfig? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.tap = tap; self.doubleTap = doubleTap
        self.press = press; self.hold = hold
        self.drag = drag; self.pan = pan
        self.accessibility = accessibility
        self.child = child()
    }

    public func makeRenderer() -> ProxyRenderer {
        GestureRenderer(view: self)
    }
}

// MARK: - Renderer

final class GestureRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var gestureView: GestureView?
    private var view: Gesture

    init(view: Gesture) { self.view = view }

    func update(from newView: any View) {
        guard let gesture = newView as? Gesture, let gestureView else { return }
        view = gesture
        gestureView.configure(gesture)
    }

    func mount() -> PlatformView {
        let v = GestureView()
        self.gestureView = v
        v.configure(view)
        return v
    }
}

// MARK: - GestureView

final class GestureView: UIView {
    private var tapRecognizer: UITapGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var panRecognizer: UIPanGestureRecognizer?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var rotationRecognizer: UIRotationGestureRecognizer?

    private var tapConfig: TapConfig?
    private var doubleTapConfig: DoubleTapConfig?
    private var pressConfig: PressConfig?
    private var holdConfig: HoldConfig?
    private var dragConfig: DragConfig?
    private var panConfig: PanConfig?

    // Drag tracking
    private var dragInitialLocal: Vec2 = .zero
    private var dragInitialGlobal: Vec2 = .zero
    private var dragLastLocal: Vec2 = .zero

    // Hold tracking
    private var holdStartTime: Double = 0
    private var holdRecognized = false
    private var holdInitialLocal: Vec2 = .zero
    private var holdInitialGlobal: Vec2 = .zero
    private var holdLastLocal: Vec2 = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? size
    }

    override var intrinsicContentSize: CGSize {
        subviews.first?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for child in subviews {
            child.frame = bounds
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        let local = touch.location(in: self)
        let global = touch.location(in: nil)
        let pos = GesturePosition(
            local: Vec2(Double(local.x), Double(local.y)),
            global: Vec2(Double(global.x), Double(global.y))
        )
        tapConfig?.onDown?(pos)
        doubleTapConfig?.onDown?(pos)
        pressConfig?.onDown?(pos)
        holdConfig?.onDown?(pos)
        dragConfig?.onDown?(pos)
        panConfig?.onDown?(pos)
    }

    private var accessibilityConfig: AccessibilityConfig?

    func configure(_ gesture: Gesture) {
        configureTap(gesture.tap)
        configureDoubleTap(gesture.doubleTap)
        configurePress(gesture.press, hold: gesture.hold)
        configureDrag(gesture.drag)
        configurePan(gesture.pan)
        configureAccessibility(gesture.accessibility)
    }

    private func configureAccessibility(_ config: AccessibilityConfig?) {
        accessibilityConfig = config
        isAccessibilityElement = config != nil
        accessibilityTraits = config?.traits.uiTraits ?? []
        accessibilityLabel = config?.label
        accessibilityValue = config?.value
    }

    override func accessibilityActivate() -> Bool {
        accessibilityConfig?.activate?() ?? false
    }

    override func accessibilityIncrement() {
        accessibilityConfig?.increment?()
    }

    override func accessibilityDecrement() {
        accessibilityConfig?.decrement?()
    }

    // MARK: - Tap

    private func configureTap(_ config: TapConfig?) {
        tapConfig = config
        if config != nil {
            if tapRecognizer == nil {
                let r = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                addGestureRecognizer(r)
                tapRecognizer = r
            }
        } else if let r = tapRecognizer {
            removeGestureRecognizer(r)
            tapRecognizer = nil
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let config = tapConfig else { return }
        let pos = gesturePosition(g)
        config.onStart?(TapStart(position: pos))
        config.onEnd?(TapEnd(position: pos))
    }

    // MARK: - Double Tap

    private func configureDoubleTap(_ config: DoubleTapConfig?) {
        doubleTapConfig = config
        if config != nil {
            if doubleTapRecognizer == nil {
                let r = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
                r.numberOfTapsRequired = 2
                addGestureRecognizer(r)
                doubleTapRecognizer = r
                tapRecognizer?.require(toFail: r)
            }
        } else if let r = doubleTapRecognizer {
            removeGestureRecognizer(r)
            doubleTapRecognizer = nil
        }
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        guard let config = doubleTapConfig else { return }
        let pos = gesturePosition(g)
        config.onEnd?(DoubleTapEnd(position: pos, firstTapPosition: pos))
    }

    // MARK: - Press / Hold

    private func configurePress(_ press: PressConfig?, hold: HoldConfig?) {
        pressConfig = press
        holdConfig = hold
        let needsRecognizer = press != nil || hold != nil
        if needsRecognizer {
            if longPressRecognizer == nil {
                let r = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                addGestureRecognizer(r)
                longPressRecognizer = r
            }
            let duration = press?.pressDuration ?? hold?.holdThreshold ?? 0.5
            longPressRecognizer?.minimumPressDuration = duration
            longPressRecognizer?.allowableMovement = CGFloat(press?.slop ?? hold?.slop ?? 10)
        } else if let r = longPressRecognizer {
            removeGestureRecognizer(r)
            longPressRecognizer = nil
        }
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        let pos = gesturePosition(g)
        switch g.state {
        case .began:
            holdStartTime = CACurrentMediaTime()
            holdInitialLocal = pos.local
            holdInitialGlobal = pos.global
            holdLastLocal = pos.local
            holdRecognized = true
            pressConfig?.onStart?(LongPressStart(position: pos))
            holdConfig?.onStart?(LongPressStart(position: pos))
        case .changed:
            let elapsed = CACurrentMediaTime() - holdStartTime
            let delta = pos.local - holdLastLocal
            let totalDelta = pos.local - holdInitialLocal
            holdLastLocal = pos.local
            pressConfig?.onUpdate?(LongPressUpdate(position: pos, delta: delta, totalDelta: totalDelta, elapsed: elapsed))
            holdConfig?.onUpdate?(LongPressUpdate(position: pos, delta: delta, totalDelta: totalDelta, elapsed: elapsed))
        case .ended:
            let elapsed = CACurrentMediaTime() - holdStartTime
            let totalDelta = pos.local - holdInitialLocal
            pressConfig?.onEnd?(LongPressEnd(position: pos, totalDelta: totalDelta, elapsed: elapsed))
            holdConfig?.onEnd?(LongPressEnd(position: pos, totalDelta: totalDelta, elapsed: elapsed))
            holdRecognized = false
        case .cancelled, .failed:
            pressConfig?.onCancel?()
            holdConfig?.onCancel?()
            holdRecognized = false
        default: break
        }
    }

    // MARK: - Drag

    private func configureDrag(_ config: DragConfig?) {
        dragConfig = config
        if config != nil {
            if panRecognizer == nil {
                let r = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                addGestureRecognizer(r)
                panRecognizer = r
            }
        } else if panConfig == nil, let r = panRecognizer {
            removeGestureRecognizer(r)
            panRecognizer = nil
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let pos = gesturePosition(g)
        let vel = g.velocity(in: self)

        switch g.state {
        case .began:
            dragInitialLocal = pos.local
            dragInitialGlobal = pos.global
            dragLastLocal = pos.local
            dragConfig?.onStart?(DragStart(
                position: pos,
                initialPosition: GesturePosition(local: dragInitialLocal, global: dragInitialGlobal)
            ))
        case .changed:
            let delta = pos.local - dragLastLocal
            let totalDelta = pos.local - dragInitialLocal
            dragLastLocal = pos.local
            dragConfig?.onUpdate?(DragUpdate(
                position: pos,
                delta: delta,
                totalDelta: totalDelta
            ))
        case .ended:
            let totalDelta = pos.local - dragInitialLocal
            dragConfig?.onEnd?(DragEnd(
                position: pos,
                totalDelta: totalDelta,
                velocity: Vec2(Double(vel.x), Double(vel.y))
            ))
        case .cancelled, .failed:
            dragConfig?.onCancel?()
        default: break
        }
    }

    // MARK: - Pan (multi-pointer)

    private func configurePan(_ config: PanConfig?) {
        panConfig = config
        if config != nil {
            if pinchRecognizer == nil {
                let r = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                addGestureRecognizer(r)
                pinchRecognizer = r
            }
            if rotationRecognizer == nil {
                let r = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
                addGestureRecognizer(r)
                rotationRecognizer = r
            }
            pinchRecognizer?.delegate = self
            rotationRecognizer?.delegate = self
        } else {
            if let r = pinchRecognizer { removeGestureRecognizer(r); pinchRecognizer = nil }
            if let r = rotationRecognizer { removeGestureRecognizer(r); rotationRecognizer = nil }
        }
    }

    private var lastScale: CGFloat = 1
    private var lastRotation: CGFloat = 0
    private var totalScale: CGFloat = 1
    private var totalRotation: CGFloat = 0
    private var panStartFocal: Vec2 = .zero
    private var panLastFocal: Vec2 = .zero

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard let config = panConfig else { return }
        let focal = focalPoint(g)
        let pos = GesturePosition(local: focal, global: globalPoint(focal))

        switch g.state {
        case .began:
            lastScale = 1; totalScale = 1
            panStartFocal = focal; panLastFocal = focal
            config.onStart?(PanStart(position: pos, pointerCount: g.numberOfTouches))
        case .changed:
            let scaleDelta = g.scale / lastScale
            lastScale = g.scale
            totalScale *= scaleDelta
            let focalDelta = focal - panLastFocal
            let totalFocalDelta = focal - panStartFocal
            panLastFocal = focal
            config.onUpdate?(PanUpdate(
                position: pos,
                focalDelta: focalDelta, totalFocalDelta: totalFocalDelta,
                scale: Double(totalScale), scaleDelta: Double(scaleDelta),
                rotation: Double(totalRotation), rotationDelta: 0,
                pointerCount: g.numberOfTouches
            ))
        case .ended:
            let totalFocalDelta = focal - panStartFocal
            config.onEnd?(PanEnd(
                position: pos,
                totalFocalDelta: totalFocalDelta,
                scale: Double(totalScale), rotation: Double(totalRotation),
                velocity: .zero, pointerCount: g.numberOfTouches
            ))
        case .cancelled, .failed:
            config.onCancel?()
        default: break
        }
    }

    @objc private func handleRotation(_ g: UIRotationGestureRecognizer) {
        guard panConfig != nil else { return }
        switch g.state {
        case .began:
            lastRotation = 0; totalRotation = 0
        case .changed:
            let delta = g.rotation - lastRotation
            lastRotation = g.rotation
            totalRotation += delta
        default: break
        }
    }

    // MARK: - Helpers

    private func gesturePosition(_ g: UIGestureRecognizer) -> GesturePosition {
        let local = g.location(in: self)
        let global = g.location(in: nil)
        return GesturePosition(
            local: Vec2(Double(local.x), Double(local.y)),
            global: Vec2(Double(global.x), Double(global.y))
        )
    }

    private func focalPoint(_ g: UIGestureRecognizer) -> Vec2 {
        let p = g.location(in: self)
        return Vec2(Double(p.x), Double(p.y))
    }

    private func globalPoint(_ local: Vec2) -> Vec2 {
        let p = convert(CGPoint(x: local.x, y: local.y), to: nil)
        return Vec2(Double(p.x), Double(p.y))
    }
}

// MARK: - UIGestureRecognizerDelegate

extension GestureView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        let isPinchOrRotation = gestureRecognizer is UIPinchGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer
        let otherIsPinchOrRotation = other is UIPinchGestureRecognizer || other is UIRotationGestureRecognizer
        return isPinchOrRotation && otherIsPinchOrRotation
    }
}

// MARK: - TapHandler

/// Single-tap gesture with flat API.
///
/// ```swift
/// TapHandler(
///     onDown: { pos in pressed = true },
///     onEnd: { e in doAction() },
///     onCancel: { pressed = false }
/// ) {
///     MyContent()
/// }
/// ```
public struct TapHandler: BuiltView {
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (TapStart) -> Void)?
    public let onEnd: (@MainActor (TapEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (TapStart) -> Void)? = nil,
        onEnd: (@MainActor (TapEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.onDown = onDown; self.onStart = onStart; self.onEnd = onEnd
        self.onCancel = onCancel; self.accessibility = accessibility
        self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            tap: TapConfig(onDown: onDown, onStart: onStart, onEnd: onEnd, onCancel: onCancel),
            accessibility: accessibility
        ) { child }
    }
}

// MARK: - DoubleTapHandler

/// Double-tap gesture with flat API.
public struct DoubleTapHandler: BuiltView {
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (DoubleTapStart) -> Void)?
    public let onEnd: (@MainActor (DoubleTapEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (DoubleTapStart) -> Void)? = nil,
        onEnd: (@MainActor (DoubleTapEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.onDown = onDown; self.onStart = onStart; self.onEnd = onEnd
        self.onCancel = onCancel; self.accessibility = accessibility
        self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            doubleTap: DoubleTapConfig(onDown: onDown, onStart: onStart, onEnd: onEnd, onCancel: onCancel),
            accessibility: accessibility
        ) { child }
    }
}

// MARK: - PressHandler

/// Press gesture with flat API. Use `duration: 0` for instant
/// touch-down/up tracking (e.g. button press state).
///
/// ```swift
/// PressHandler(
///     duration: 0,
///     onDown: { pos in model.handleDown() },
///     onStart: { e in model.handlePress() },
///     onEnd: { e in model.handleRelease() },
///     onCancel: { model.handleRelease() }
/// ) {
///     Box(style) { content }
/// }
/// ```
public struct PressHandler: BuiltView {
    public let duration: Double
    public let slop: Double
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (LongPressStart) -> Void)?
    public let onUpdate: (@MainActor (LongPressUpdate) -> Void)?
    public let onEnd: (@MainActor (LongPressEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        duration: Double = 0.5,
        slop: Double = 10,
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (LongPressStart) -> Void)? = nil,
        onUpdate: (@MainActor (LongPressUpdate) -> Void)? = nil,
        onEnd: (@MainActor (LongPressEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.duration = duration; self.slop = slop
        self.onDown = onDown; self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
        self.accessibility = accessibility; self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            press: PressConfig(
                pressDuration: duration, slop: slop,
                onDown: onDown, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd, onCancel: onCancel
            ),
            accessibility: accessibility
        ) { child }
    }
}

// MARK: - HoldHandler

/// Long-hold gesture with flat API.
public struct HoldHandler: BuiltView {
    public let threshold: Double
    public let slop: Double
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (LongPressStart) -> Void)?
    public let onUpdate: (@MainActor (LongPressUpdate) -> Void)?
    public let onEnd: (@MainActor (LongPressEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        threshold: Double = 0.8,
        slop: Double = 10,
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (LongPressStart) -> Void)? = nil,
        onUpdate: (@MainActor (LongPressUpdate) -> Void)? = nil,
        onEnd: (@MainActor (LongPressEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.threshold = threshold; self.slop = slop
        self.onDown = onDown; self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
        self.accessibility = accessibility; self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            hold: HoldConfig(
                holdThreshold: threshold, slop: slop,
                onDown: onDown, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd, onCancel: onCancel
            ),
            accessibility: accessibility
        ) { child }
    }
}

// MARK: - DragHandler

/// Single-finger drag gesture with flat API.
///
/// ```swift
/// DragHandler(
///     onDown: { pos in ... },
///     onStart: { e in ... },
///     onUpdate: { e in offset += e.delta },
///     onEnd: { e in snap(velocity: e.velocity) }
/// ) {
///     MyDraggableContent()
/// }
/// ```
public struct DragHandler: BuiltView {
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (DragStart) -> Void)?
    public let onUpdate: (@MainActor (DragUpdate) -> Void)?
    public let onEnd: (@MainActor (DragEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (DragStart) -> Void)? = nil,
        onUpdate: (@MainActor (DragUpdate) -> Void)? = nil,
        onEnd: (@MainActor (DragEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.onDown = onDown; self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
        self.accessibility = accessibility; self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            drag: DragConfig(
                onDown: onDown, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd, onCancel: onCancel
            ),
            accessibility: accessibility
        ) { child }
    }
}

// MARK: - PanHandler

/// Multi-finger gesture (pinch + rotation) with flat API.
public struct PanHandler: BuiltView {
    public let minPointers: Int
    public let onDown: (@MainActor (GesturePosition) -> Void)?
    public let onStart: (@MainActor (PanStart) -> Void)?
    public let onUpdate: (@MainActor (PanUpdate) -> Void)?
    public let onEnd: (@MainActor (PanEnd) -> Void)?
    public let onCancel: (@MainActor () -> Void)?
    public let accessibility: AccessibilityConfig?
    public let child: any View

    public init(
        minPointers: Int = 2,
        onDown: (@MainActor (GesturePosition) -> Void)? = nil,
        onStart: (@MainActor (PanStart) -> Void)? = nil,
        onUpdate: (@MainActor (PanUpdate) -> Void)? = nil,
        onEnd: (@MainActor (PanEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        accessibility: AccessibilityConfig? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.minPointers = minPointers
        self.onDown = onDown; self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
        self.accessibility = accessibility; self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        Gesture(
            pan: PanConfig(
                minPointers: minPointers,
                onDown: onDown, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd, onCancel: onCancel
            ),
            accessibility: accessibility
        ) { child }
    }
}

#endif
