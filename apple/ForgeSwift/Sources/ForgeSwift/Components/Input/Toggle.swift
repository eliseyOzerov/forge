#if canImport(UIKit)
import UIKit
import Foundation

// MARK: - TogglePainter

/// Draws a toggle's visual state onto a Canvas.
/// Receives UIState (.selected = on, .pressed = finger down) and the
/// curved animation progress (0 = off, 1 = on).
public protocol TogglePainter {
    func paint(on canvas: Canvas, bounds: Rect, state: UIState, progress: Double)
}

// MARK: - Toggle

public struct Toggle: ModelView {
    public let value: Binding<Bool>
    public let painter: any TogglePainter
    public let size: Size
    public let animation: StateProperty<Animation>
    public let label: String?

    public init(
        value: Binding<Bool>,
        painter: any TogglePainter,
        size: Size = Size(24, 24),
        animation: StateProperty<Animation> = .constant(.default),
        label: String? = nil
    ) {
        self.value = value
        self.painter = painter
        self.size = size
        self.animation = animation
        self.label = label
    }

    public func makeModel(context: BuildContext) -> ToggleModel { ToggleModel() }
    public func makeBuilder() -> ToggleBuilder { ToggleBuilder() }
}

// MARK: - Model

public final class ToggleModel: ViewModel<Toggle> {
    var isPressed = false
    lazy var motion: Motion = Motion(
        duration: 0.2,
        tracks: [Track(from: 0, to: 1)]
    )

    public override func didInit() {
        let anim = resolveAnimation()
        motion = Motion(
            duration: anim.duration,
            curve: anim.curve,
            tracks: [Track(from: 0, to: 1)]
        )
        if view.value.value {
            motion.target([1])
            // Snap immediately
            motion.tick()
            while motion.isRunning { motion.tick() }
        }
    }

    public override func didUpdate(from oldView: Toggle) {}

    /// Resolve animation for the *current* state — describes how to exit it.
    private func resolveAnimation() -> Animation {
        view.animation(currentState)
    }

    var isOn: Bool { view.value.value }
    var animationProgress: Double { motion.values[0] }
    var isAnimating: Bool { motion.isRunning }

    var currentState: UIState {
        var state: UIState = .idle
        if isOn || animationProgress > 0.5 { state.insert(.selected) }
        if isPressed { state.insert(.pressed) }
        return state
    }

    func handlePress() {
        let anim = resolveAnimation()
        motion.duration = anim.duration
        motion.curve = anim.curve
        rebuild { isPressed = true }
    }

    func handleRelease(inside: Bool) {
        let wasPressed = isPressed
        let anim = resolveAnimation()
        motion.duration = anim.duration
        motion.curve = anim.curve
        rebuild { isPressed = false }
        if inside && wasPressed { toggle() }
    }

    func toggle() {
        view.value.value.toggle()
        let anim = resolveAnimation()
        motion.duration = anim.duration
        motion.curve = anim.curve
        motion.target([view.value.value ? 1 : 0])
        node?.markDirty()
    }
}

// MARK: - Builder

public final class ToggleBuilder: ViewBuilder<ToggleModel> {
    public override func build(context: BuildContext) -> any View {
        ToggleLeaf(model: model)
    }
}

// MARK: - Leaf

struct ToggleLeaf: LeafView {
    let model: ToggleModel
    func makeRenderer() -> Renderer { ToggleRenderer(model: model) }
}

// MARK: - Renderer

final class ToggleRenderer: Renderer {
    let model: ToggleModel

    init(model: ToggleModel) { self.model = model }

    func mount() -> PlatformView {
        let view = ToggleView()
        view.model = model
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? ToggleView else { return }
        view.model = model
        apply(to: view)
    }

    private func apply(to view: ToggleView) {
        view.toggleSize = model.view.size
        view.isOpaque = false
        view.backgroundColor = .clear
        view.invalidateIntrinsicContentSize()
        if model.isAnimating { view.startAnimation() }
        view.setNeedsDisplay()
    }
}

// MARK: - ToggleView

final class ToggleView: UIView {
    weak var model: ToggleModel?
    var toggleSize: Size = Size(24, 24)
    private let driver = DisplayLinkDriver()

    override var intrinsicContentSize: CGSize { toggleSize.cgSize }
    override func sizeThatFits(_ size: CGSize) -> CGSize { toggleSize.cgSize }

    func startAnimation() {
        driver.motion = model?.motion
        driver.attach(to: self)
        driver.start()
    }

    override func draw(_ rect: CGRect) {
        guard let model, let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvas = CGCanvas(ctx)
        let bounds = Rect(x: 0, y: 0, width: Double(rect.width), height: Double(rect.height))
        model.view.painter.paint(on: canvas, bounds: bounds, state: model.currentState, progress: model.animationProgress)
    }

    // MARK: Touch

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

    // MARK: Accessibility

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { [.button] } set {} }
    override var accessibilityLabel: String? { get { model?.view.label } set {} }
    override var accessibilityValue: String? { get { model?.isOn == true ? "on" : "off" } set {} }
    override func accessibilityActivate() -> Bool { model?.toggle(); return true }

    override func removeFromSuperview() { driver.stop(); super.removeFromSuperview() }
}

// MARK: - Preset: Checkbox

public struct CheckboxPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.5, 1.0), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: UIState, progress: Double) {
        let inset = bounds.width * 0.1
        let r = Rect(x: bounds.x + inset, y: bounds.y + inset, width: bounds.width - inset * 2, height: bounds.height - inset * 2)
        let cornerRadius = r.width * 0.2
        let strokeWidth = r.width * 0.08
        let pressed = state.contains(.pressed)
        let scale = pressed ? 0.9 : 1.0

        if scale != 1.0 {
            canvas.save()
            canvas.translate(bounds.midX, bounds.midY)
            canvas.scale(scale, scale)
            canvas.translate(-bounds.midX, -bounds.midY)
        }

        // Background
        canvas.fillRoundedRect(r, radius: cornerRadius, color: offColor.lerp(to: onColor, t: progress))

        // Border (fades out)
        if progress < 1 {
            var border = Path(); border.addRoundedRect(r, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            canvas.draw(border.stroked(width: strokeWidth), with: Paint(.color(offColor.withAlpha(1 - progress)), opacity: 0.5))
        }

        // Checkmark
        if progress > 0 {
            var check = Path()
            check.move(to: Point(r.x + r.width * 0.22, r.y + r.height * 0.52))
            check.line(to: Point(r.x + r.width * 0.42, r.y + r.height * 0.72))
            check.line(to: Point(r.x + r.width * 0.78, r.y + r.height * 0.32))
            canvas.draw(check.stroked(width: strokeWidth * 1.5, cap: .round, join: .round), with: Paint(.color(.white), opacity: progress))
        }

        if scale != 1.0 { canvas.restore() }
    }
}

// MARK: - Preset: Radio

public struct RadioPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.5, 1.0), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: UIState, progress: Double) {
        let center = Vec2(bounds.midX, bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 * 0.8
        let innerRadius = outerRadius * 0.5
        let strokeWidth = outerRadius * 0.12
        let pressed = state.contains(.pressed)
        let scale = pressed ? 0.9 : 1.0

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

public struct SwitchPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(0.2, 0.8, 0.4), offColor: Color = Color(0.8, 0.8, 0.8)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: UIState, progress: Double) {
        let h = bounds.height * 0.6
        let w = h * 1.8
        let x = bounds.midX - w / 2
        let y = bounds.midY - h / 2
        let trackRect = Rect(x: x, y: y, width: w, height: h)
        let pressed = state.contains(.pressed)

        // Track
        canvas.fillRoundedRect(trackRect, radius: h / 2, color: offColor.lerp(to: onColor, t: progress))

        // Thumb
        let pad = h * 0.12
        let thumbR = (h - pad * 2) / 2
        let expand = pressed ? thumbR * 0.15 : 0
        let minX = x + pad + thumbR
        let maxX = x + w - pad - thumbR
        let thumbX = minX + (maxX - minX) * progress

        canvas.fillCircle(center: Vec2(thumbX, bounds.midY), radius: thumbR + expand, color: .white)
    }
}

// MARK: - Preset: Heart

public struct HeartPainter: TogglePainter {
    public let onColor: Color
    public let offColor: Color

    public init(onColor: Color = Color(1, 0.2, 0.3), offColor: Color = Color(0.7, 0.7, 0.7)) {
        self.onColor = onColor; self.offColor = offColor
    }

    public func paint(on canvas: Canvas, bounds: Rect, state: UIState, progress: Double) {
        let pressed = state.contains(.pressed)
        let scale = pressed ? 0.85 : 1.0
        let s = min(bounds.width, bounds.height) * 0.8

        if scale != 1.0 {
            canvas.save()
            canvas.translate(bounds.midX, bounds.midY)
            canvas.scale(scale, scale)
            canvas.translate(-bounds.midX, -bounds.midY)
        }

        let heart = Self.heartPath(center: Vec2(bounds.midX, bounds.midY), size: s)

        if progress > 0 {
            canvas.draw(heart, with: Paint(.color(onColor), opacity: progress))
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
        animation: StateProperty<Animation> = .constant(.default),
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, painter: CheckboxPainter(onColor: onColor, offColor: offColor), size: Size(size, size), animation: animation, label: label)
    }

    static func radio(
        value: Binding<Bool>,
        size: Double = 24,
        onColor: Color = Color(0.2, 0.5, 1.0),
        offColor: Color = Color(0.7, 0.7, 0.7),
        animation: StateProperty<Animation> = .constant(.default),
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, painter: RadioPainter(onColor: onColor, offColor: offColor), size: Size(size, size), animation: animation, label: label)
    }

    static func `switch`(
        value: Binding<Bool>,
        height: Double = 32,
        onColor: Color = Color(0.2, 0.8, 0.4),
        offColor: Color = Color(0.8, 0.8, 0.8),
        animation: StateProperty<Animation> = .constant(Animation(duration: 0.25)),
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, painter: SwitchPainter(onColor: onColor, offColor: offColor), size: Size(height * 1.8, height), animation: animation, label: label)
    }

    static func heart(
        value: Binding<Bool>,
        size: Double = 28,
        onColor: Color = Color(1, 0.2, 0.3),
        offColor: Color = Color(0.7, 0.7, 0.7),
        animation: StateProperty<Animation> = StateProperty { state in
            state.contains(.pressed) ? .fast : Animation(duration: 0.25, curve: .overshoot)
        },
        label: String? = nil
    ) -> Toggle {
        Toggle(value: value, painter: HeartPainter(onColor: onColor, offColor: offColor), size: Size(size, size), animation: animation, label: label)
    }
}

#endif
