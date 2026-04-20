#if canImport(UIKit)
import UIKit

// MARK: - SegmentedStyle

public struct SegmentedStyle<T> {
    public var background: StateProperty<BoxStyle>
    public var selector: @MainActor (T, State) -> any View
    public var item: @MainActor (T, State) -> any View
    public var divider: StateProperty<BoxStyle>?
    public var foreground: StateProperty<BoxStyle>?
    public var axis: Axis
    public var animation: Animation
    public var haptic: HapticStyle
    public var dragEnabled: Bool

    public init(
        background: StateProperty<BoxStyle> = .constant(BoxStyle(
            frame: .fillWidth.height(.hug()),
            surface: .color(Color(0.93, 0.93, 0.95)),
            shape: .roundedRect(radius: 8),
            padding: Padding(all: 2)
        )),
        selector: @escaping @MainActor (T, State) -> any View = { _, _ in
            Box(BoxStyle(frame: .fill, surface: .color(.white), shape: .roundedRect(radius: 6)))
        },
        item: @escaping @MainActor (T, State) -> any View = { value, _ in
            Text("\(value)", style: TextStyle(font: Font(size: 14), align: .center))
        },
        divider: StateProperty<BoxStyle>? = nil,
        foreground: StateProperty<BoxStyle>? = nil,
        axis: Axis = .horizontal,
        animation: Animation = Animation(duration: 0.25, curve: .easeOut),
        haptic: HapticStyle = .light,
        dragEnabled: Bool = true
    ) {
        self.background = background
        self.selector = selector
        self.item = item
        self.divider = divider
        self.foreground = foreground
        self.axis = axis
        self.animation = animation
        self.haptic = haptic
        self.dragEnabled = dragEnabled
    }
}

// MARK: - Segmented

public struct Segmented<T: Hashable>: ModelView {
    public let value: Binding<T>
    public let items: [T]
    public let states: State
    public let label: String?
    public let style: StateProperty<SegmentedStyle<T>>

    public init(
        value: Binding<T>,
        items: [T],
        states: State = .idle,
        label: String? = nil,
        style: StateProperty<SegmentedStyle<T>> = .constant(SegmentedStyle<T>())
    ) {
        self.value = value
        self.items = items
        self.states = states
        self.label = label
        self.style = style
    }

    public func model(context: ViewContext) -> SegmentedModel<T> { SegmentedModel(context: context) }
    public func builder(model: SegmentedModel<T>) -> SegmentedBuilder<T> { SegmentedBuilder(model: model) }
}

// MARK: - Model

public final class SegmentedModel<T: Hashable>: ViewModel<Segmented<T>> {
    var isPressed = false
    let driver = MotionDriver(duration: Duration(0.25))
    var curve: Curve = .easeInOut
    private var animFrom: Double = 0
    private var animTo: Double = 0

    public override func didInit(view: Segmented<T>) {
        super.didInit(view: view)
        let idx = Double(selectedIndex)
        let style = view.style(.idle)
        driver.duration = Duration(style.animation.duration)
        curve = style.animation.curve
        animFrom = idx
        animTo = idx
        watch(driver)
    }

    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }

    var currentState: State {
        var state = view.states
        if isPressed { state.insert(.pressed) }
        return state
    }

    var itemCount: Int { view.items.count }

    var selectedIndex: Int {
        view.items.firstIndex(of: view.value.value) ?? 0
    }

    /// Visual position as a float index (0..count-1), possibly between
    /// segments during animation or drag.
    var displayIndex: Double {
        if driver.isRunning {
            let eased = curve(driver.value)
            return animFrom + (animTo - animFrom) * eased
        }
        return Double(selectedIndex)
    }

    func itemState(at index: Int) -> State {
        var state = view.states
        if index == selectedIndex { state.insert(.selected) }
        return state
    }

    // MARK: Interaction

    func tapSegment(at index: Int) {
        guard !isDisabled, !isLoading, (0..<itemCount).contains(index) else { return }
        animateToIndex(index)
    }

    func scrubStart() {
        guard !isDisabled, !isLoading else { return }
        rebuild { isPressed = true }
    }

    func scrubTo(normalized: Double) {
        guard isPressed else { return }
        rebuild {
            let clamped = min(max(normalized, 0), 1)
            let idx = clamped * Double(itemCount - 1)
            animFrom = idx
            animTo = idx
            driver.seek(to: 1)
            // Update value when crossing midpoint
            let nearest = Int(idx.rounded())
            if (0..<itemCount).contains(nearest) {
                let newItem = view.items[nearest]
                if newItem != view.value.value {
                    view.value.value = newItem
                    fireHaptic()
                }
            }
        }
    }

    func scrubEnd() {
        isPressed = false
        animateToIndex(selectedIndex)
    }

    private func animateToIndex(_ index: Int) {
        rebuild {
            let newItem = view.items[index]
            if newItem != view.value.value {
                view.value.value = newItem
                fireHaptic()
            }
            let style = view.style(currentState)
            driver.duration = Duration(style.animation.duration)
            curve = style.animation.curve
            animFrom = displayIndex
            animTo = Double(index)
            driver.seek(to: 0)
        }
        Task { [weak self] in await self?.driver.forward() }
    }

    private func fireHaptic() {
        let style = view.style(currentState)
        guard style.haptic != .none else { return }
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style.haptic {
        case .light: .light; case .medium: .medium; case .heavy: .heavy
        case .rigid: .rigid; case .soft: .soft; case .none: .light
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }
}

// MARK: - Builder

public final class SegmentedBuilder<T: Hashable>: ViewBuilder<SegmentedModel<T>> {
    public override func build(context: ViewContext) -> any View {
        let model = self.model
        return LayoutReader { [weak model] size in
            guard let model else { return EmptyView() }
            return SegmentedBuilder<T>.buildLayers(size: size, model: model)
        }
    }

    @MainActor
    private static func buildLayers(size: Size, model: SegmentedModel<T>) -> any View {
        let style = model.view.style(model.currentState)
        let itemCount = max(model.itemCount, 1)
        let segmentWidth = size.width / Double(itemCount)
        let selectorX = segmentWidth * model.displayIndex
        let selectorItem = model.view.items[model.selectedIndex]

        let itemViews: [any View] = model.view.items.enumerated().map { pair in
            Box(BoxStyle(frame: .fill)) {
                style.item(pair.element, model.itemState(at: pair.offset))
            }
        }

        return Box(style.background(model.currentState)) {
            // Items row (deselected baseline)
            Row(children: itemViews)

            // Selector, positioned via leading padding
            Box(BoxStyle(
                frame: .fill,
                padding: Padding(leading: selectorX),
                alignment: .topLeft
            )) {
                Box(frame: .fixed(segmentWidth, size.height)) {
                    style.selector(selectorItem, model.currentState)
                }
            }

            // Gesture overlay
            SegmentedGestures<T>(model: model, dragEnabled: style.dragEnabled)
        }
    }
}

// MARK: - Gestures

struct SegmentedGestures<T: Hashable>: LeafView {
    let model: SegmentedModel<T>
    let dragEnabled: Bool

    func makeRenderer() -> Renderer {
        SegmentedGestureRenderer(view: self)
    }
}

final class SegmentedGestureRenderer<T: Hashable>: Renderer {
    private weak var gestureView: SegmentedGestureView<T>?
    private var view: SegmentedGestures<T>

    init(view: SegmentedGestures<T>) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let gestures = newView as? SegmentedGestures<T>, let gestureView else { return }
        let old = view
        view = gestures

        gestureView.model = gestures.model
        if old.dragEnabled != gestures.dragEnabled {
            gestureView.dragEnabled = gestures.dragEnabled
        }
    }

    func mount() -> PlatformView {
        let v = SegmentedGestureView<T>()
        self.gestureView = v
        v.model = view.model
        v.dragEnabled = view.dragEnabled
        v.installGestures()
        return v
    }
}

final class SegmentedGestureView<T: Hashable>: UIView {
    weak var model: SegmentedModel<T>?
    var dragEnabled: Bool = true
    private var tap: UITapGestureRecognizer?
    private var pan: UIPanGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize { size }

    func installGestures() {
        if tap == nil {
            let t = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            addGestureRecognizer(t)
            tap = t
        }
        if pan == nil {
            let p = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(p)
            pan = p
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let model, bounds.width > 0 else { return }
        let x = g.location(in: self).x
        let norm = min(max(Double(x) / Double(bounds.width), 0), 1)
        let idx = Int((norm * Double(model.itemCount)).rounded(.down))
        model.tapSegment(at: min(idx, model.itemCount - 1))
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard dragEnabled, let model, bounds.width > 0 else { return }
        let x = g.location(in: self).x
        let norm = min(max(Double(x) / Double(bounds.width), 0), 1)
        switch g.state {
        case .began:
            model.scrubStart()
            model.scrubTo(normalized: norm)
        case .changed:
            model.scrubTo(normalized: norm)
        case .ended, .cancelled:
            model.scrubEnd()
        default: break
        }
    }
}

// MARK: - SegmentedRole

public struct SegmentedRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension SegmentedRole {
    static let primary    = SegmentedRole("primary")
    static let secondary  = SegmentedRole("secondary")
    static let tertiary   = SegmentedRole("tertiary")
    static let quaternary = SegmentedRole("quaternary")

    static let defaultChain: [SegmentedRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - SegmentedTheme

public struct SegmentedTheme<T>: Copyable {
    public var styles: [SegmentedRole: SegmentedStyle<T>]
    public var chain: [SegmentedRole]

    public init(_ styles: [SegmentedRole: SegmentedStyle<T>], chain: [SegmentedRole] = SegmentedRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(
        primary: SegmentedStyle<T>,
        secondary: SegmentedStyle<T>? = nil,
        tertiary: SegmentedStyle<T>? = nil,
        quaternary: SegmentedStyle<T>? = nil
    ) {
        var map: [SegmentedRole: SegmentedStyle<T>] = [.primary: primary]
        if let s = secondary  { map[.secondary]  = s }
        if let t = tertiary   { map[.tertiary]   = t }
        if let q = quaternary { map[.quaternary] = q }
        self.init(map)
    }

    public subscript(_ role: SegmentedRole) -> SegmentedStyle<T> {
        styles.cascade(role, chain: chain) ?? SegmentedStyle<T>()
    }

    public var primary:    SegmentedStyle<T> { self[.primary] }
    public var secondary:  SegmentedStyle<T> { self[.secondary] }
    public var tertiary:   SegmentedStyle<T> { self[.tertiary] }
    public var quaternary: SegmentedStyle<T> { self[.quaternary] }

    public static func standard() -> SegmentedTheme<T> {
        SegmentedTheme(primary: SegmentedStyle<T>())
    }
}

#endif
