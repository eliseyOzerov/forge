import Foundation

// MARK: - Config Types

public struct LongPressConfig {
    public var delay: Double
    public var interval: Double
    public var acceleration: Double

    public init(delay: Double = 0.5, interval: Double = 0.15, acceleration: Double = 0.9) {
        self.delay = delay; self.interval = interval; self.acceleration = acceleration
    }

    nonisolated(unsafe) public static let `default` = LongPressConfig()
}

public struct DragConfig {
    public var sensitivity: Double
    public var axis: Axis
    public var enabled: Bool

    public init(sensitivity: Double = 10, axis: Axis = .vertical, enabled: Bool = true) {
        self.sensitivity = sensitivity; self.axis = axis; self.enabled = enabled
    }

    nonisolated(unsafe) public static let `default` = DragConfig()
}

public enum TransitionDirection { case up, down, fade }

public struct ValueTransition {
    public var animation: Animation
    public var direction: TransitionDirection

    public init(animation: Animation = .fast, direction: TransitionDirection = .up) {
        self.animation = animation; self.direction = direction
    }

    nonisolated(unsafe) public static let `default` = ValueTransition()
}

// MARK: - StepperStyle

/// Configuration for a stepper +/- button: its visual style and optional custom content.
public struct StepperButton {
    public var style: ButtonStyle
    public var view: (any View)?

    public init(
        style: ButtonStyle = ButtonStyle(BoxStyle(.square(36), .color(Color(0.9, 0.9, 0.9)), .roundedRect(radius: 6)), textStyle: TextStyle(font: Font(size: 18, weight: 600))),
        view: (any View)? = nil
    ) {
        self.style = style; self.view = view
    }
}

public struct StepperStyle<T> {
    public var container: BoxStyle
    public var field: BoxStyle
    public var decrement: StepperButton
    public var increment: StepperButton
    public var text: TextStyle
    public var spacing: Double
    public var formatter: TextFormatter<T>?
    public var longPress: LongPressConfig
    public var drag: DragConfig
    public var haptic: HapticStyle
    public var transition: ValueTransition

    public init(
        container: BoxStyle = BoxStyle(padding: .zero),
        field: BoxStyle = BoxStyle(.hug, .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 6), padding: Padding(horizontal: 8, vertical: 4)),
        decrement: StepperButton = StepperButton(),
        increment: StepperButton = StepperButton(),
        text: TextStyle = TextStyle(font: Font(size: 16), align: .center),
        spacing: Double = 4,
        formatter: TextFormatter<T>? = nil,
        longPress: LongPressConfig = .default,
        drag: DragConfig = .default,
        haptic: HapticStyle = .light,
        transition: ValueTransition = .default
    ) {
        self.container = container; self.field = field
        self.decrement = decrement; self.increment = increment
        self.text = text; self.spacing = spacing; self.formatter = formatter
        self.longPress = longPress; self.drag = drag
        self.haptic = haptic; self.transition = transition
    }
}

#if canImport(UIKit)
import UIKit

// MARK: - Stepper

public struct Stepper<T: Numeric & Comparable & LosslessStringConvertible>: ModelView {
    public let value: Binding<T>
    public let range: ClosedRange<T>
    public let step: T
    public let states: UIState
    public let label: String?
    public let style: StateProperty<StepperStyle<T>>

    public init(
        value: Binding<T>,
        range: ClosedRange<T>,
        step: T,
        states: UIState = .idle,
        label: String? = nil,
        style: StateProperty<StepperStyle<T>> = .constant(StepperStyle())
    ) {
        self.value = value; self.range = range; self.step = step
        self.states = states; self.label = label; self.style = style
    }

    public func makeModel(context: BuildContext) -> StepperModel<T> { StepperModel() }
    public func makeBuilder() -> StepperBuilder<T> { StepperBuilder() }
}

// MARK: - Model

public final class StepperModel<T: Numeric & Comparable & LosslessStringConvertible>: ViewModel<Stepper<T>> {
    var isEditing = false
    var dragAccumulator: Double = 0
    private var repeatTimer: Timer?
    private var currentRepeatInterval: Double = 0

    public override func didInit() {}

    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }

    var currentValue: T {
        get { view.value.value }
        set { view.value.value = clamp(newValue) }
    }

    var atMin: Bool { currentValue <= view.range.lowerBound }
    var atMax: Bool { currentValue >= view.range.upperBound }

    var currentState: UIState {
        var state = view.states
        if isEditing { state.insert(.focused) }
        return state
    }

    func displayText() -> String {
        let style = view.style(currentState)
        if let formatter = style.formatter { return formatter(currentValue) }
        return "\(currentValue)"
    }

    // MARK: Increment / Decrement

    func increment() {
        guard !isDisabled, !isLoading, !atMax else { return }
        currentValue = currentValue + view.step
        fireHaptic()
        node?.markDirty()
    }

    func decrement() {
        guard !isDisabled, !isLoading, !atMin else { return }
        currentValue = currentValue - view.step
        fireHaptic()
        node?.markDirty()
    }

    // MARK: Long Press Repeat

    func startRepeat(incrementing: Bool) {
        guard !isDisabled, !isLoading else { return }
        let style = view.style(currentState)
        currentRepeatInterval = style.longPress.interval

        repeatTimer = Timer.scheduledTimer(withTimeInterval: style.longPress.delay, repeats: false) { [weak self] _ in
            self?.fireRepeat(incrementing: incrementing)
        }
    }

    private func fireRepeat(incrementing: Bool) {
        guard !isDisabled, !isLoading else { stopRepeat(); return }
        if incrementing { increment() } else { decrement() }

        let style = view.style(currentState)
        currentRepeatInterval *= style.longPress.acceleration

        repeatTimer = Timer.scheduledTimer(withTimeInterval: currentRepeatInterval, repeats: false) { [weak self] _ in
            self?.fireRepeat(incrementing: incrementing)
        }
    }

    func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: Drag

    func handleDrag(delta: Double) {
        guard !isDisabled, !isLoading else { return }
        let style = view.style(currentState)
        guard style.drag.enabled else { return }

        dragAccumulator += delta
        let steps = Int(dragAccumulator / style.drag.sensitivity)
        if steps != 0 {
            dragAccumulator -= Double(steps) * style.drag.sensitivity
            if let stepValue = T(exactly: abs(steps)) {
                let change = stepValue * view.step
                if steps < 0 { // drag up = increment (negative delta)
                    currentValue = currentValue + change
                } else {
                    currentValue = currentValue - change
                }
                fireHaptic()
                node?.markDirty()
            }
        }
    }

    func resetDrag() {
        dragAccumulator = 0
    }

    // MARK: Text Edit

    func textChanged(_ text: String) {
        guard let parsed = T(text) else { return }
        currentValue = parsed
        node?.markDirty()
    }

    func setEditing(_ editing: Bool) {
        rebuild { isEditing = editing }
    }

    // MARK: Helpers

    private func clamp(_ value: T) -> T {
        min(max(value, view.range.lowerBound), view.range.upperBound)
    }

    private func fireHaptic() {
        let style = view.style(currentState)
        guard style.haptic != .none else { return }
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style.haptic {
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

public final class StepperBuilder<T: Numeric & Comparable & LosslessStringConvertible>: ViewBuilder<StepperModel<T>> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)

        let decContent: any View = style.decrement.view ?? Text("−", style: style.decrement.style.textStyle)
        let incContent: any View = style.increment.view ?? Text("+", style: style.increment.style.textStyle)

        let decStyle = model.atMin ? dimmed(style.decrement.style) : style.decrement.style
        let incStyle = model.atMax ? dimmed(style.increment.style) : style.increment.style

        return Box(style.container) {
            Row(spacing: style.spacing, alignment: .center) {
                Button(
                    style: .constant(decStyle),
                    states: model.atMin ? .disabled : model.view.states,
                    onTap: { [weak model] in model?.decrement() }
                ) { decContent }
                StepperFieldLeaf(model: model, style: style)
                Button(
                    style: .constant(incStyle),
                    states: model.atMax ? .disabled : model.view.states,
                    onTap: { [weak model] in model?.increment() }
                ) { incContent }
            }
        }
    }

    private func dimmed(_ style: ButtonStyle) -> ButtonStyle {
        ButtonStyle(style.box, textStyle: TextStyle(font: style.textStyle.font, color: .gray), haptic: .none, animation: style.animation)
    }
}

// MARK: - StepperFieldLeaf

struct StepperFieldLeaf<T: Numeric & Comparable & LosslessStringConvertible>: LeafView {
    let model: StepperModel<T>
    let style: StepperStyle<T>

    func makeRenderer() -> Renderer {
        StepperFieldRenderer(model: model, style: style)
    }
}

// MARK: - StepperFieldRenderer

final class StepperFieldRenderer<T: Numeric & Comparable & LosslessStringConvertible>: Renderer {
    let model: StepperModel<T>
    let style: StepperStyle<T>

    init(model: StepperModel<T>, style: StepperStyle<T>) {
        self.model = model; self.style = style
    }

    func mount() -> PlatformView {
        let view = StepperFieldView<T>()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? StepperFieldView<T> else { return }
        apply(to: view)
    }

    private func apply(to view: StepperFieldView<T>) {
        let field = view.textField
        field.text = model.displayText()
        field.font = style.text.font.resolvedFont
        field.textColor = style.text.color ?? .label
        field.textAlignment = style.text.align.nsTextAlignment
        field.keyboardType = .decimalPad

        view.model = model
        view.dragAxis = style.drag.axis
        view.dragEnabled = style.drag.enabled
        view.sizing = style.field.frame
        view.surface = style.field.surface
        view.shape = style.field.shape
        view.padding = style.field.padding
        view.setNeedsDisplay()
    }
}

// MARK: - StepperFieldView

final class StepperFieldView<T: Numeric & Comparable & LosslessStringConvertible>: BoxView, UITextFieldDelegate {
    let textField = UITextField()
    weak var model: StepperModel<T>?
    var dragAxis: Axis = .vertical
    var dragEnabled: Bool = true
    private var panGesture: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        textField.delegate = self
        textField.borderStyle = .none
        textField.textAlignment = .center
        addSubview(textField)

        textField.addAction(UIAction { [weak self] _ in
            self?.model?.textChanged(self?.textField.text ?? "")
        }, for: .editingChanged)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        textField.frame = CGRect(
            x: padding.leading, y: padding.top,
            width: bounds.width - padding.leading - padding.trailing,
            height: bounds.height - padding.top - padding.bottom
        )
    }

    // MARK: Pan Gesture

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard dragEnabled, !textField.isFirstResponder else { return }

        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: self)
            let delta = dragAxis == .vertical ? Double(translation.y) : Double(-translation.x)
            model?.handleDrag(delta: delta)
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            model?.resetDrag()
        default: break
        }
    }

    // MARK: Text Field Delegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        model?.setEditing(true)
        panGesture.isEnabled = false
        scrollIntoViewIfNeeded()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        model?.setEditing(false)
        panGesture.isEnabled = dragEnabled
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func scrollIntoViewIfNeeded() {
        var ancestor: UIView? = superview
        while let v = ancestor {
            if let scrollView = v as? UIScrollView {
                let rect = convert(bounds, to: scrollView)
                scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -20), animated: true)
                return
            }
            ancestor = v.superview
        }
    }

    // MARK: Accessibility

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { .adjustable } set {} }
    override var accessibilityLabel: String? { get { model?.view.label } set {} }
    override var accessibilityValue: String? { get { model?.displayText() } set {} }

    override func accessibilityIncrement() { model?.increment() }
    override func accessibilityDecrement() { model?.decrement() }
}

#endif
