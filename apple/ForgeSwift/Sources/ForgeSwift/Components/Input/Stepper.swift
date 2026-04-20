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

public struct StepperDragConfig {
    public var sensitivity: Double
    public var axis: Axis
    public var enabled: Bool

    public init(sensitivity: Double = 10, axis: Axis = .vertical, enabled: Bool = true) {
        self.sensitivity = sensitivity; self.axis = axis; self.enabled = enabled
    }

    nonisolated(unsafe) public static let `default` = StepperDragConfig()
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
        style: ButtonStyle = .box(.frame(.square(36)).surface(.color(Color(0.9, 0.9, 0.9))).shape(.roundedRect(radius: 6))).textStyle(.font(.size(18).weight(600))),
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
    public var drag: StepperDragConfig
    public var haptic: HapticStyle
    public var transition: ValueTransition

    public init(
        container: BoxStyle = .padding(.zero),
        field: BoxStyle = .surface(.color(Color(0.95, 0.95, 0.95))).shape(.roundedRect(radius: 6)).padding(Padding(horizontal: 8, vertical: 4)),
        decrement: StepperButton = StepperButton(),
        increment: StepperButton = StepperButton(),
        text: TextStyle = .font(.size(16)).align(.center),
        spacing: Double = 4,
        formatter: TextFormatter<T>? = nil,
        longPress: LongPressConfig = .default,
        drag: StepperDragConfig = .default,
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
    public let states: State
    public let label: String?
    public let style: StateProperty<StepperStyle<T>>

    public init(
        value: Binding<T>,
        range: ClosedRange<T>,
        step: T,
        states: State = .idle,
        label: String? = nil,
        style: StateProperty<StepperStyle<T>> = .constant(StepperStyle())
    ) {
        self.value = value; self.range = range; self.step = step
        self.states = states; self.label = label; self.style = style
    }

    public func model(context: ViewContext) -> StepperModel<T> { StepperModel(context: context) }
    public func builder(model: StepperModel<T>) -> StepperBuilder<T> { StepperBuilder(model: model) }
}

// MARK: - Model

public final class StepperModel<T: Numeric & Comparable & LosslessStringConvertible>: ViewModel<Stepper<T>> {
    var isEditing = false
    var dragAccumulator: Double = 0
    private var repeatTimer: Timer?
    private var currentRepeatInterval: Double = 0

    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }

    var currentValue: T {
        get { view.value.value }
        set { view.value.value = clamp(newValue) }
    }

    var atMin: Bool { currentValue <= view.range.lowerBound }
    var atMax: Bool { currentValue >= view.range.upperBound }

    var currentState: State {
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
        rebuild { currentValue = currentValue + view.step }
        fireHaptic()
    }

    func decrement() {
        guard !isDisabled, !isLoading, !atMin else { return }
        rebuild { currentValue = currentValue - view.step }
        fireHaptic()
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
                rebuild {
                    if steps < 0 { // drag up = increment (negative delta)
                        currentValue = currentValue + change
                    } else {
                        currentValue = currentValue - change
                    }
                }
                fireHaptic()
            }
        }
    }

    func resetDrag() {
        dragAccumulator = 0
    }

    // MARK: Text Edit

    func textChanged(_ text: String) {
        rebuild {
            guard let parsed = T(text) else { return }
            currentValue = parsed
        }
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
    public override func build(context: ViewContext) -> any View {
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
        ButtonStyle.box(style.box).textStyle(.font(style.textStyle.font).color(.gray)).haptic(.none).animation(style.animation)
    }
}

// MARK: - StepperFieldLeaf

struct StepperFieldLeaf<T: Numeric & Comparable & LosslessStringConvertible>: LeafView {
    let model: StepperModel<T>
    let style: StepperStyle<T>

    func makeRenderer() -> Renderer {
        StepperFieldRenderer(view: self)
    }
}

// MARK: - StepperFieldRenderer

final class StepperFieldRenderer<T: Numeric & Comparable & LosslessStringConvertible>: Renderer {
    private weak var fieldView: StepperFieldView<T>?
    private var view: StepperFieldLeaf<T>

    init(view: StepperFieldLeaf<T>) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let leaf = newView as? StepperFieldLeaf<T>, let fieldView else { return }
        view = leaf

        // Apply model props
        fieldView.model = leaf.model
        fieldView.textField.text = leaf.model.displayText()

        // Apply style props
        let field = fieldView.textField
        field.font = (leaf.style.text.font ?? Font()).resolvedFont
        field.textColor = leaf.style.text.color?.platformColor ?? .label
        field.textAlignment = (leaf.style.text.align ?? .center).nsTextAlignment

        fieldView.dragAxis = leaf.style.drag.axis
        fieldView.dragEnabled = leaf.style.drag.enabled

        fieldView.sizing = leaf.style.field.frame
        fieldView.surface = leaf.style.field.surface
        fieldView.shape = leaf.style.field.shape
        fieldView.padding = leaf.style.field.padding
        fieldView.invalidateIntrinsicContentSize()
        fieldView.setNeedsDisplay()
        fieldView.superview?.setNeedsLayout()
    }

    func mount() -> PlatformView {
        let fv = StepperFieldView<T>()
        self.fieldView = fv
        let field = fv.textField
        field.text = view.model.displayText()
        field.font = (view.style.text.font ?? Font()).resolvedFont
        field.textColor = view.style.text.color?.platformColor ?? .label
        field.textAlignment = (view.style.text.align ?? .center).nsTextAlignment
        field.keyboardType = .decimalPad

        fv.model = view.model
        fv.dragAxis = view.style.drag.axis
        fv.dragEnabled = view.style.drag.enabled
        fv.sizing = view.style.field.frame
        fv.surface = view.style.field.surface
        fv.shape = view.style.field.shape
        fv.padding = view.style.field.padding
        return fv
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
