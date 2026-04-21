#if canImport(UIKit)
import UIKit
import Foundation

// MARK: - Toggle

/// A boolean toggle rendered by a pluggable painter (checkbox, radio, switch, heart).
public struct Toggle: ModelView {
    public let value: Binding<Bool>
    public let style: StateProperty<ToggleStyle>
    public let states: State
    public let label: String?

    public init(
        value: Binding<Bool>,
        style: StateProperty<ToggleStyle> = .constant(ToggleStyle()),
        states: State = .idle,
        label: String? = nil
    ) {
        self.value = value
        self.style = style
        self.states = states
        self.label = label
    }

    public func model(context: ViewContext) -> ToggleModel { ToggleModel(context: context) }
    public func builder(model: ToggleModel) -> ToggleBuilder { ToggleBuilder(model: model) }
}

// MARK: - ToggleStyle

/// Visual styling for Toggle.
public struct ToggleStyle {
    public var painter: any TogglePainter
    public var size: Size
    public var animation: Animation
    public var haptic: HapticStyle

    public init(
        painter: any TogglePainter = CheckboxPainter(),
        size: Size = Size(24, 24),
        animation: Animation = .default,
        haptic: HapticStyle = .light
    ) {
        self.painter = painter
        self.size = size
        self.animation = animation
        self.haptic = haptic
    }
}

// MARK: - TogglePainter

/// Draws a toggle's visual state onto a Canvas.
/// Receives State (.selected = on, .pressed = finger down) and the
/// curved animation progress (0 = off, 1 = on).
public protocol TogglePainter {
    func paint(on canvas: Canvas, bounds: Rect, state: State, progress: Double)
}

// MARK: - Model

/// View model managing on/off state, press feedback, and animation driver for Toggle.
public final class ToggleModel: ViewModel<Toggle> {
    var isPressed = false
    let driver = MotionDriver(duration: Duration(0.2))
    var curve: Curve = .easeInOut

    public override func didInit(view: Toggle) {
        super.didInit(view: view)
        let style = resolveStyle()
        driver.duration = Duration(style.animation.duration)
        curve = style.animation.curve
        if view.value.value {
            driver.seek(to: 1)
        }
    }

    var isOn: Bool { view.value.value }
    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }
    var animationProgress: Double { curve(driver.value) }
    var isAnimating: Bool { driver.isRunning }

    var currentState: State {
        var state = view.states
        if isOn || animationProgress > 0.5 { state.insert(.selected) }
        if isPressed { state.insert(.pressed) }
        return state
    }

    /// Resolve style for current state.
    func resolveStyle() -> ToggleStyle {
        view.style(currentState)
    }

    func handlePress() {
        guard !isDisabled, !isLoading else { return }
        let style = resolveStyle()
        driver.duration = Duration(style.animation.duration)
        curve = style.animation.curve
        rebuild { isPressed = true }
        fireHaptic(style.haptic)
    }

    func handleRelease(inside: Bool) {
        let wasPressed = isPressed
        let style = resolveStyle()
        driver.duration = Duration(style.animation.duration)
        curve = style.animation.curve
        rebuild { isPressed = false }
        if inside && wasPressed { toggle() }
    }

    func toggle() {
        rebuild {
            view.value.value.toggle()
            let style = resolveStyle()
            driver.duration = Duration(style.animation.duration)
            curve = style.animation.curve
        }
        Task { [weak self] in
            guard let self else { return }
            if isOn {
                await driver.forward()
            } else {
                await driver.reverse()
            }
        }
    }

    private func fireHaptic(_ haptic: HapticStyle) {
        guard haptic != .none else { return }
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch haptic {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .rigid: .rigid
        case .soft: .soft
        case .none: .light
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }
}

// MARK: - Builder

/// Builds the Toggle view tree by wrapping content in a ToggleLeaf.
public final class ToggleBuilder: ViewBuilder<ToggleModel> {
    public override func build(context: ViewContext) -> any View {
        ToggleLeaf(model: model)
    }
}

// MARK: - Leaf

/// Leaf view that bridges Toggle into a platform-specific canvas renderer.
struct ToggleLeaf: LeafView {
    let model: ToggleModel
    func makeRenderer() -> Renderer { ToggleRenderer(view: self) }
}

// MARK: - Renderer

final class ToggleRenderer: Renderer {
    private weak var toggleView: ToggleView?
    private var view: ToggleLeaf

    init(view: ToggleLeaf) { self.view = view }

    func update(from newView: any View) {
        guard let leaf = newView as? ToggleLeaf, let toggleView else { return }
        let old = view
        view = leaf

        toggleView.model = leaf.model
        let style = leaf.model.resolveStyle()
        let oldStyle = old.model.resolveStyle()
        let sizeChanged = style.size != oldStyle.size
        toggleView.toggleSize = style.size
        if sizeChanged {
            toggleView.invalidateIntrinsicContentSize()
            toggleView.superview?.setNeedsLayout()
        }
        toggleView.setNeedsDisplay()
    }

    func mount() -> PlatformView {
        let tv = ToggleView()
        self.toggleView = tv
        tv.model = view.model
        let style = view.model.resolveStyle()
        tv.toggleSize = style.size
        tv.isOpaque = false
        tv.backgroundColor = .clear
        tv.invalidateIntrinsicContentSize()
        tv.wireDriver()
        return tv
    }
}

// MARK: - ToggleView

final class ToggleView: UIView {
    weak var model: ToggleModel?
    var toggleSize: Size = Size(24, 24)
    private var progressSub: Subscription?

    override var intrinsicContentSize: CGSize { toggleSize.cgSize }
    override func sizeThatFits(_ size: CGSize) -> CGSize { toggleSize.cgSize }

    func wireDriver() {
        progressSub = model?.driver.listen { [weak self] in
            self?.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let model, let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvas = CGCanvas(ctx)
        let bounds = Rect(x: 0, y: 0, width: Double(rect.width), height: Double(rect.height))
        let style = model.resolveStyle()
        style.painter.paint(on: canvas, bounds: bounds, state: model.currentState, progress: model.animationProgress)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        model?.handlePress()
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let inside = touches.first.map { bounds.contains($0.location(in: self)) } ?? false
        model?.handleRelease(inside: inside)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        model?.handleRelease(inside: false)
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { [.button] } set {} }
    override var accessibilityLabel: String? { get { model?.view.label } set {} }
    override var accessibilityValue: String? { get { model?.isOn == true ? "on" : "off" } set {} }
    override func accessibilityActivate() -> Bool { model?.toggle(); return true }

    override func removeFromSuperview() { progressSub?.cancel(); model?.driver.reset(); super.removeFromSuperview() }
}

// MARK: - Preset: Checkbox

/// Painter that draws a checkbox with an animated checkmark.
public struct CheckboxPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.5, 1.0), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: State, progress: Double) {
        let inset = bounds.width * 0.1
        let r = Rect(x: bounds.x + inset, y: bounds.y + inset, width: bounds.width - inset * 2, height: bounds.height - inset * 2)
        let cornerRadius = r.width * 0.2
        let strokeWidth = r.width * 0.08
        let scale = state.contains(.pressed) ? 0.9 : 1.0

        if scale != 1.0 {
            canvas.save()
            canvas.translate(bounds.midX, bounds.midY)
            canvas.scale(scale, scale)
            canvas.translate(-bounds.midX, -bounds.midY)
        }

        canvas.fillRoundedRect(r, radius: cornerRadius, color: offColor.lerp(to: onColor, t: progress))

        if progress < 1 {
            var border = Path(); border.addRoundedRect(r, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            canvas.draw(border.stroked(width: strokeWidth), with: Paint(ColorFill(offColor.withAlpha(1 - progress)), opacity: 0.5))
        }

        if progress > 0 {
            var check = Path()
            check.move(to: Point(r.x + r.width * 0.22, r.y + r.height * 0.52))
            check.line(to: Point(r.x + r.width * 0.42, r.y + r.height * 0.72))
            check.line(to: Point(r.x + r.width * 0.78, r.y + r.height * 0.32))
            canvas.draw(check.stroked(width: strokeWidth * 1.5, cap: .round, join: .round), with: Paint(ColorFill(.white), opacity: progress))
        }

        if scale != 1.0 { canvas.restore() }
    }
}

// MARK: - Preset: Radio

/// Painter that draws a radio button with an animated inner dot.
public struct RadioPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.5, 1.0), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: State, progress: Double) {
        let center = Vec2(bounds.midX, bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 * 0.8
        let innerRadius = outerRadius * 0.5
        let strokeWidth = outerRadius * 0.12
        let scale = state.contains(.pressed) ? 0.9 : 1.0

        if scale != 1.0 {
            canvas.save()
            canvas.translate(bounds.midX, bounds.midY)
            canvas.scale(scale, scale)
            canvas.translate(-bounds.midX, -bounds.midY)
        }

        canvas.strokeCircle(center: center, radius: outerRadius, color: offColor.lerp(to: onColor, t: progress), width: strokeWidth)
        if progress > 0 {
            canvas.fillCircle(center: center, radius: innerRadius * progress, color: onColor.withAlpha(progress))
        }

        if scale != 1.0 { canvas.restore() }
    }
}

// MARK: - Preset: Switch

/// Painter that draws a sliding switch track and thumb.
public struct SwitchPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.8, 0.4), offColor: Color = Color(0.8, 0.8, 0.8)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: State, progress: Double) {
        let h = bounds.height * 0.6
        let w = h * 1.8
        let x = bounds.midX - w / 2
        let y = bounds.midY - h / 2
        let trackRect = Rect(x: x, y: y, width: w, height: h)

        canvas.fillRoundedRect(trackRect, radius: h / 2, color: offColor.lerp(to: onColor, t: progress))

        let pad = h * 0.12
        let thumbR = (h - pad * 2) / 2
        let expand = state.contains(.pressed) ? thumbR * 0.15 : 0
        let minX = x + pad + thumbR
        let maxX = x + w - pad - thumbR
        let thumbX = minX + (maxX - minX) * progress

        canvas.fillCircle(center: Vec2(thumbX, bounds.midY), radius: thumbR + expand, color: .white)
    }
}

// MARK: - Preset: Heart

/// Painter that draws a heart shape that fills on toggle.
public struct HeartPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(1, 0.2, 0.3), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: State, progress: Double) {
        let scale = state.contains(.pressed) ? 0.85 : 1.0
        let s = min(bounds.width, bounds.height) * 0.8

        if scale != 1.0 {
            canvas.save()
            canvas.translate(bounds.midX, bounds.midY)
            canvas.scale(scale, scale)
            canvas.translate(-bounds.midX, -bounds.midY)
        }

        let heart = Self.heartPath(center: Vec2(bounds.midX, bounds.midY), size: s)

        if progress > 0 {
            canvas.draw(heart, with: Paint(ColorFill(onColor), opacity: progress))
        }
        let outline = heart.stroked(width: s * 0.06, cap: .round, join: .round)
        canvas.draw(outline, with: .color(offColor.lerp(to: onColor, t: progress)))

        if scale != 1.0 { canvas.restore() }
    }

    public static func heartPath(center: Vec2, size: Double) -> Path {
        let s = size, cx = center.x, cy = center.y
        let top = cy - s * 0.25
        var p = Path()
        p.move(to: Point(cx, cy + s * 0.3))
        p.curve(to: Point(cx - s * 0.5, top), control1: Point(cx - s * 0.15, cy + s * 0.15), control2: Point(cx - s * 0.5, cy))
        p.curve(to: Point(cx, cy - s * 0.05), control1: Point(cx - s * 0.5, top - s * 0.2), control2: Point(cx - s * 0.15, top - s * 0.15))
        p.curve(to: Point(cx + s * 0.5, top), control1: Point(cx + s * 0.15, top - s * 0.15), control2: Point(cx + s * 0.5, top - s * 0.2))
        p.curve(to: Point(cx, cy + s * 0.3), control1: Point(cx + s * 0.5, cy), control2: Point(cx + s * 0.15, cy + s * 0.15))
        p.close()
        return p
    }
}

// MARK: - Convenience Factories

public extension Toggle {
    static func checkbox(
        value: Binding<Bool>,
        size: Double = 24,
        onColor: Color = Color(0.2, 0.5, 1.0),
        offColor: Color = Color(0.7, 0.7, 0.7),
        states: State = .idle,
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, style: StateProperty { state in
            ToggleStyle(
                painter: CheckboxPainter(onColor: onColor, offColor: offColor),
                size: Size(size, size),
                animation: state.contains(.pressed) ? .fast : .default,
                haptic: state.contains(.pressed) ? .light : .none
            )
        }, states: states, label: label)
    }

    static func radio(
        value: Binding<Bool>,
        size: Double = 24,
        onColor: Color = Color(0.2, 0.5, 1.0),
        offColor: Color = Color(0.7, 0.7, 0.7),
        states: State = .idle,
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, style: StateProperty { state in
            ToggleStyle(
                painter: RadioPainter(onColor: onColor, offColor: offColor),
                size: Size(size, size),
                animation: state.contains(.pressed) ? .fast : .default,
                haptic: state.contains(.pressed) ? .light : .none
            )
        }, states: states, label: label)
    }

    static func `switch`(
        value: Binding<Bool>,
        height: Double = 32,
        onColor: Color = Color(0.2, 0.8, 0.4),
        offColor: Color = Color(0.8, 0.8, 0.8),
        states: State = .idle,
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, style: StateProperty { state in
            ToggleStyle(
                painter: SwitchPainter(onColor: onColor, offColor: offColor),
                size: Size(height * 1.8, height),
                animation: state.contains(.pressed) ? .fast : Animation(duration: 0.25),
                haptic: state.contains(.pressed) ? .medium : .none
            )
        }, states: states, label: label)
    }

    static func heart(
        value: Binding<Bool>,
        size: Double = 28,
        onColor: Color = Color(1, 0.2, 0.3),
        offColor: Color = Color(0.7, 0.7, 0.7),
        states: State = .idle,
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, style: StateProperty { state in
            ToggleStyle(
                painter: HeartPainter(onColor: onColor, offColor: offColor),
                size: Size(size, size),
                animation: state.contains(.pressed) ? .fast : Animation(duration: 0.25, curve: .overshoot),
                haptic: state.contains(.pressed) ? .light : .none
            )
        }, states: states, label: label)
    }
}

// MARK: - ToggleRole

/// Named toggle role token.
public struct ToggleRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension ToggleRole {
    static let primary    = ToggleRole("primary")
    static let secondary  = ToggleRole("secondary")
    static let tertiary   = ToggleRole("tertiary")
    static let quaternary = ToggleRole("quaternary")

    static let defaultChain: [ToggleRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - ToggleTheme

/// Theme for toggles.
public struct ToggleTheme: Copyable {
    public var styles: [ToggleRole: ToggleStyle]
    public var chain: [ToggleRole]

    public init(_ styles: [ToggleRole: ToggleStyle], chain: [ToggleRole] = ToggleRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<ToggleStyle>) {
        var map: [ToggleRole: ToggleStyle] = [:]
        for (level, style) in priority.values {
            map[ToggleRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: ToggleStyle,
        secondary: ToggleStyle? = nil,
        tertiary: ToggleStyle? = nil,
        quaternary: ToggleStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: ToggleRole) -> ToggleStyle {
        styles.cascade(role, chain: chain) ?? ToggleStyle()
    }

    public var primary:    ToggleStyle { self[.primary] }
    public var secondary:  ToggleStyle { self[.secondary] }
    public var tertiary:   ToggleStyle { self[.tertiary] }
    public var quaternary: ToggleStyle { self[.quaternary] }

    public static func standard() -> ToggleTheme {
        ToggleTheme(primary: ToggleStyle())
    }
}

public extension ThemeSlot where T == ToggleTheme {
    static var toggle: ThemeSlot<ToggleTheme> { .init(ToggleTheme.self) }
}

#endif
