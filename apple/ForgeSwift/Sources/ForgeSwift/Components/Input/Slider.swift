import Foundation

// MARK: - TrackStyle

public struct TrackStyle {
    public var inactive: BoxStyle
    public var active: BoxStyle
    public var mark: BoxStyle?
    public var divisions: TrackDivisions?

    public init(
        inactive: BoxStyle = BoxStyle(.fillWidth.height(.fix(4)), .color(Color(0.85, 0.85, 0.85)), .capsule()),
        active: BoxStyle = BoxStyle(.fillWidth.height(.fix(4)), .color(Color(0.2, 0.5, 1.0)), .capsule()),
        mark: BoxStyle? = nil,
        divisions: TrackDivisions? = nil
    ) {
        self.inactive = inactive; self.active = active
        self.mark = mark; self.divisions = divisions
    }
}

public struct TrackDivisions {
    public var count: Int
    public var magnetStrength: Double
    public var label: DivisionLabelStyle?

    public init(
        count: Int = 5,
        magnetStrength: Double = 0,
        label: DivisionLabelStyle? = nil
    ) {
        self.count = count; self.magnetStrength = magnetStrength; self.label = label
    }
}

public struct DivisionLabelStyle {
    public var text: TextStyle
    public var placement: Alignment
    public var formatter: TextFormatter<Double>?
    public var show: Mapper<Double, Bool>?

    public init(
        text: TextStyle = TextStyle(font: Font(size: 10)),
        placement: Alignment = .bottomCenter,
        formatter: TextFormatter<Double>? = nil,
        show: Mapper<Double, Bool>? = nil
    ) {
        self.text = text; self.placement = placement
        self.formatter = formatter; self.show = show
    }
}

// MARK: - ThumbStyle

public struct ThumbStyle {
    public var box: BoxStyle
    public var label: ThumbLabelStyle?

    public init(
        box: BoxStyle = BoxStyle(.square(24), .color(.white).shadow(blur: 4), .circle()),
        label: ThumbLabelStyle? = nil
    ) {
        self.box = box; self.label = label
    }
}

public struct ThumbLabelStyle {
    public var text: TextStyle
    public var box: BoxStyle
    public var visible: Bool
    public var formatter: TextFormatter<Double>?

    public init(
        text: TextStyle = TextStyle(font: Font(size: 12, weight: 600), color: .white),
        box: BoxStyle = BoxStyle(.hug, .color(Color(0.2, 0.2, 0.2)), .capsule(), padding: Padding(horizontal: 8, vertical: 4)),
        visible: Bool = false,
        formatter: TextFormatter<Double>? = nil
    ) {
        self.text = text; self.box = box; self.visible = visible; self.formatter = formatter
    }
}

// MARK: - SliderStyle

public struct SliderStyle {
    public var track: StateProperty<TrackStyle>
    public var thumb: StateProperty<ThumbStyle>
    public var axis: Axis
    public var origin: Alignment
    public var haptic: HapticStyle
    public var animation: Animation

    public init(
        track: StateProperty<TrackStyle> = .constant(TrackStyle()),
        thumb: StateProperty<ThumbStyle> = .constant(ThumbStyle()),
        axis: Axis = .horizontal,
        origin: Alignment = .centerLeft,
        haptic: HapticStyle = .light,
        animation: Animation = Animation(duration: 0.2, curve: .easeOut)
    ) {
        self.track = track; self.thumb = thumb; self.axis = axis
        self.origin = origin; self.haptic = haptic; self.animation = animation
    }
}

// MARK: - Slider

#if canImport(UIKit)
import UIKit

public struct Slider: ModelView {
    public let value: Binding<Double>
    public let range: ClosedRange<Double>
    public let states: State
    public let label: String?
    public let style: StateProperty<SliderStyle>

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        states: State = .idle,
        label: String? = nil,
        style: StateProperty<SliderStyle> = .constant(SliderStyle())
    ) {
        self.value = value; self.range = range
        self.states = states; self.label = label; self.style = style
    }

    public func model(context: ViewContext) -> SliderModel { SliderModel(context: context) }
    public func builder(model: SliderModel) -> SliderBuilder { SliderBuilder(model: model) }
}

// MARK: - Model

public final class SliderModel: ViewModel<Slider> {
    var isPressed = false
    var motion: Motion = Motion(duration: 0.2, tracks: [Track()])

    public override func didInit(view: Slider) {
        super.didInit(view: view)
        motion = Motion(duration: 0.2, curve: .easeOut, tracks: [Track(from: normalized, to: normalized)])
    }

    var isDisabled: Bool { view.states.contains(.disabled) }

    var currentState: State {
        var state = view.states
        if isPressed { state.insert(.pressed) }
        return state
    }

    /// Value normalized to 0...1.
    var normalized: Double {
        let range = view.range
        guard range.upperBound > range.lowerBound else { return 0 }
        return (view.value.value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Current visual position (may differ during animation).
    var displayNormalized: Double {
        motion.isRunning ? motion.values[0] : normalized
    }

    func setNormalized(_ n: Double, animated: Bool = false) {
        rebuild {
            let clamped = min(max(n, 0), 1)
            let range = view.range
            let newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)

            // Snap to divisions if needed
            let style = resolveStyle()
            let trackStyle = style.track(currentState)
            if let div = trackStyle.divisions, div.magnetStrength > 0, div.count > 0 {
                let step = 1.0 / Double(div.count)
                let snapped = (clamped / step).rounded() * step
                let pulled = clamped + (snapped - clamped) * div.magnetStrength
                let snappedValue = range.lowerBound + pulled * (range.upperBound - range.lowerBound)
                view.value.value = snappedValue
            } else {
                view.value.value = newValue
            }

            if animated {
                let style = resolveStyle()
                motion = Motion(duration: style.animation.duration, curve: style.animation.curve, tracks: [Track(from: displayNormalized, to: self.normalized)])
                motion.forward()
            }

            fireHaptic()
        }
    }

    func handlePress(at normalizedPosition: Double) {
        guard !isDisabled else { return }
        rebuild { isPressed = true }
        setNormalized(normalizedPosition, animated: true)
    }

    func handleDrag(at normalizedPosition: Double) {
        guard isPressed else { return }
        setNormalized(normalizedPosition)
    }

    func handleRelease() {
        rebuild { isPressed = false }
    }

    func resolveStyle() -> SliderStyle {
        view.style(currentState)
    }

    private func fireHaptic() {
        let style = resolveStyle()
        guard style.haptic != .none else { return }
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style.haptic {
        case .light: .light; case .medium: .medium; case .heavy: .heavy
        case .rigid: .rigid; case .soft: .soft; case .none: .light
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }
}

// MARK: - Builder

public final class SliderBuilder: ViewBuilder<SliderModel> {
    public override func build(context: ViewContext) -> any View {
        SliderLeaf(model: model)
    }
}

// MARK: - Leaf

struct SliderLeaf: LeafView {
    let model: SliderModel
    func makeRenderer() -> Renderer { SliderRenderer(model: model) }
}

// MARK: - Renderer

final class SliderRenderer: Renderer {
    private weak var sliderView: SliderView?

    var model: SliderModel {
        didSet {
            guard let sliderView else { return }
            sliderView.model = model
            applySlider(to: sliderView)
        }
    }

    init(model: SliderModel) { self.model = model }

    func update(from view: any View) {
        guard let leaf = view as? SliderLeaf else { return }
        model = leaf.model
    }

    func mount() -> PlatformView {
        let view = SliderView()
        self.sliderView = view
        view.model = model
        applySlider(to: view)
        return view
    }

    private func applySlider(to view: SliderView) {
        view.isOpaque = false
        view.backgroundColor = .clear
        if model.motion.isRunning { view.startAnimation() }
        view.setNeedsDisplay()
    }
}

// MARK: - SliderView

final class SliderView: UIView {
    weak var model: SliderModel?
    private let driver = DisplayLinkDriver()
    private var panGesture: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    func startAnimation() {
        driver.motion = model?.motion
        driver.attach(to: self)
        driver.start()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: 44)
    }

    override func draw(_ rect: CGRect) {
        guard let model, let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvas = CGCanvas(ctx)
        let bounds = Rect(x: 0, y: 0, width: Double(rect.width), height: Double(rect.height))
        let style = model.resolveStyle()
        let isH = style.axis == .horizontal

        let trackStyle = style.track(model.currentState)
        let thumbStyle = style.thumb(model.currentState)
        let n = model.displayNormalized

        // Track geometry
        let trackHeight = 4.0
        let thumbSize = 24.0
        let trackY = bounds.midY - trackHeight / 2
        let trackRect = Rect(x: thumbSize / 2, y: trackY, width: bounds.width - thumbSize, height: trackHeight)

        // Inactive track
        canvas.fillRoundedRect(trackRect, radius: trackHeight / 2, color: trackStyle.inactive.surface?.build(shape: .rect()).isEmpty == false ? Color(0.5, 0.5, 0.5) : Color(0.85, 0.85, 0.85))

        // Active track
        let originN: Double
        if style.origin == .center { originN = 0.5 }
        else { originN = 0 }

        let activeStart = min(originN, n)
        let activeEnd = max(originN, n)
        let activeX = trackRect.x + activeStart * trackRect.width
        let activeW = (activeEnd - activeStart) * trackRect.width
        let activeRect = Rect(x: activeX, y: trackY, width: activeW, height: trackHeight)
        canvas.fillRoundedRect(activeRect, radius: trackHeight / 2, color: Color(0.2, 0.5, 1.0))

        // Division marks
        if let div = trackStyle.divisions, div.count > 0 {
            for i in 0...div.count {
                let t = Double(i) / Double(div.count)
                let x = trackRect.x + t * trackRect.width
                let markW = 2.0
                let markH = 8.0
                let markRect = Rect(x: x - markW / 2, y: bounds.midY - markH / 2, width: markW, height: markH)
                canvas.fillRoundedRect(markRect, radius: 1, color: Color(0.7, 0.7, 0.7))
            }
        }

        // Thumb
        let thumbX = trackRect.x + n * trackRect.width - thumbSize / 2
        let thumbY = bounds.midY - thumbSize / 2
        let thumbRect = Rect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)

        // Shadow
        canvas.save()
        canvas.filter(.shadow(color: Color(0, 0, 0, 0.2), offset: Vec2(0, 2), blur: 4))
        canvas.fillCircle(center: Vec2(thumbRect.midX, thumbRect.midY), radius: thumbSize / 2, color: .white)
        canvas.restore()

        // Thumb label
        if let labelStyle = thumbStyle.label, labelStyle.visible {
            let valueText = labelStyle.formatter?(model.view.value.value) ?? String(format: "%.1f", model.view.value.value)
            // Label positioning would need Text rendering on Canvas — simplified for now
            _ = valueText
        }
    }

    // MARK: Gestures

    private func normalizedPosition(from point: CGPoint) -> Double {
        let thumbSize = 24.0
        let trackStart = thumbSize / 2
        let trackWidth = Double(bounds.width) - thumbSize
        guard trackWidth > 0 else { return 0 }
        return min(max((Double(point.x) - trackStart) / trackWidth, 0), 1)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let n = normalizedPosition(from: gesture.location(in: self))
        model?.handlePress(at: n)
        model?.handleRelease()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let n = normalizedPosition(from: gesture.location(in: self))
        switch gesture.state {
        case .began:
            model?.handlePress(at: n)
        case .changed:
            model?.handleDrag(at: n)
            setNeedsDisplay()
        case .ended, .cancelled:
            model?.handleRelease()
            setNeedsDisplay()
        default: break
        }
    }

    // MARK: Accessibility

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { .adjustable } set {} }
    override var accessibilityLabel: String? { get { model?.view.label } set {} }
    override var accessibilityValue: String? {
        get { model.map { String(format: "%.0f%%", $0.normalized * 100) } }
        set {}
    }

    override func accessibilityIncrement() {
        guard let model else { return }
        let step = 1.0 / 10.0 // 10% increments for accessibility
        model.setNormalized(model.normalized + step, animated: true)
    }

    override func accessibilityDecrement() {
        guard let model else { return }
        let step = 1.0 / 10.0
        model.setNormalized(model.normalized - step, animated: true)
    }

    override func removeFromSuperview() {
        driver.stop()
        super.removeFromSuperview()
    }
}

#endif

// MARK: - SliderRole

public struct SliderRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension SliderRole {
    static let primary    = SliderRole("primary")
    static let secondary  = SliderRole("secondary")
    static let tertiary   = SliderRole("tertiary")
    static let quaternary = SliderRole("quaternary")

    static let defaultChain: [SliderRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - SliderTheme

public struct SliderTheme: Copyable {
    public var styles: [SliderRole: SliderStyle]
    public var chain: [SliderRole]

    public init(_ styles: [SliderRole: SliderStyle], chain: [SliderRole] = SliderRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<SliderStyle>) {
        var map: [SliderRole: SliderStyle] = [:]
        for (level, style) in priority.values {
            map[SliderRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: SliderStyle,
        secondary: SliderStyle? = nil,
        tertiary: SliderStyle? = nil,
        quaternary: SliderStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: SliderRole) -> SliderStyle {
        styles.cascade(role, chain: chain) ?? SliderStyle()
    }

    public var primary:    SliderStyle { self[.primary] }
    public var secondary:  SliderStyle { self[.secondary] }
    public var tertiary:   SliderStyle { self[.tertiary] }
    public var quaternary: SliderStyle { self[.quaternary] }

    public static func standard() -> SliderTheme {
        SliderTheme(primary: SliderStyle())
    }
}

public extension ThemeSlot where T == SliderTheme {
    static var slider: ThemeSlot<SliderTheme> { .init(SliderTheme.self) }
}
