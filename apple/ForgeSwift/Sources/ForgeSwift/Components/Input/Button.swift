#if canImport(UIKit)
import UIKit

// MARK: - HapticStyle

public enum HapticStyle: Sendable {
    case light, medium, heavy, rigid, soft
    case none
}

// MARK: - ButtonAnimation

public struct ButtonAnimation: Sendable {
    public var duration: Double
    public var curve: AnimationCurve

    public init(duration: Double = 0.15, curve: AnimationCurve = .easeInOut) {
        self.duration = duration
        self.curve = curve
    }

    public static let `default` = ButtonAnimation()
    public static let none = ButtonAnimation(duration: 0)

    var uiViewAnimationOptions: UIView.AnimationOptions {
        switch curve {
        case .linear: .curveLinear
        case .easeIn: .curveEaseIn
        case .easeOut: .curveEaseOut
        case .easeInOut: .curveEaseInOut
        }
    }
}

public enum AnimationCurve: Sendable {
    case linear, easeIn, easeOut, easeInOut
}

// MARK: - ButtonStyle

public struct ButtonStyle {
    public var box: BoxStyle
    public var haptic: HapticStyle
    public var animation: ButtonAnimation?

    public init(
        _ box: BoxStyle = BoxStyle(),
        haptic: HapticStyle = .light,
        animation: ButtonAnimation? = .default
    ) {
        self.box = box
        self.haptic = haptic
        self.animation = animation
    }
}

// MARK: - Button

/// A tappable component. Wraps a single child view in an interactive
/// container with state-reactive styling.
///
/// ```swift
/// Button(onTap: { print("tapped") }) {
///     Text("Tap me")
/// }
///
/// Button(
///     "Submit",
///     style: StateProperty { state in
///         ButtonStyle(
///             BoxStyle(
///                 .fillWidth.height(.fix(48)),
///                 state.contains(.pressed)
///                     ? .color(Color(0.1, 0.4, 0.9))
///                     : .color(Color(0.2, 0.5, 1.0)),
///                 .capsule(),
///                 padding: Padding(horizontal: 16)
///             ),
///             haptic: .medium
///         )
///     },
///     onTap: { }
/// )
/// ```
public struct Button: ModelView {
    public let body: any View
    public let style: StateProperty<ButtonStyle>
    public let states: UIState
    public let onTap: @MainActor () -> Void
    public let debounce: Double?
    public let label: String?

    /// Single-child button with custom content.
    public init(
        style: StateProperty<ButtonStyle> = .constant(ButtonStyle()),
        states: UIState = .idle,
        debounce: Double? = nil,
        label: String? = nil,
        onTap: @escaping @MainActor () -> Void,
        @ChildBuilder body: () -> any View
    ) {
        self.body = body()
        self.style = style
        self.states = states
        self.onTap = onTap
        self.debounce = debounce
        self.label = label
    }

    /// Text shortcut.
    public init(
        _ title: String,
        style: StateProperty<ButtonStyle> = .constant(ButtonStyle()),
        states: UIState = .idle,
        debounce: Double? = nil,
        onTap: @escaping @MainActor () -> Void
    ) {
        self.body = Text(title)
        self.style = style
        self.states = states
        self.onTap = onTap
        self.debounce = debounce
        self.label = title
    }

    public func makeModel(context: BuildContext) -> ButtonModel { ButtonModel() }
    public func makeBuilder() -> ButtonBuilder { ButtonBuilder() }
}

// MARK: - Model

public final class ButtonModel: ViewModel<Button> {
    var isPressed = false
    var onTap: (@MainActor () -> Void)?
    var lastTapTime: CFTimeInterval = 0

    public override func didInit() {
        onTap = view.onTap
    }

    public override func didUpdate(from oldView: Button) {
        onTap = view.onTap
    }

    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }

    var currentState: UIState {
        var state = view.states
        if isPressed {
            state.insert(.pressed)
            state.remove(.idle)
        } else if !isDisabled {
            state.insert(.idle)
        }
        return state
    }

    func handlePress() {
        guard !isDisabled, !isLoading else { return }
        rebuild { isPressed = true }
        fireHaptic()
    }

    func handleRelease(inside: Bool) {
        let wasPressed = isPressed
        rebuild { isPressed = false }
        guard inside, wasPressed else { return }
        if let debounce = view.debounce {
            let now = CACurrentMediaTime()
            guard now - lastTapTime >= debounce else { return }
            lastTapTime = now
        }
        onTap?()
    }

    private func fireHaptic() {
        let haptic = view.style(currentState).haptic
        guard haptic != .none else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch haptic {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .rigid: .rigid
        case .soft: .soft
        case .none: .light // unreachable
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Builder

public final class ButtonBuilder: ViewBuilder<ButtonModel> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)
        return TappableBox(style.box, model: model, animation: style.animation) {
            model.view.body
        }
    }
}

// MARK: - TappableBox

/// A Box that handles touch events and forwards to ButtonModel.
struct TappableBox: ContainerView {
    let boxStyle: BoxStyle
    let model: ButtonModel
    let animation: ButtonAnimation?
    let children: [any View]

    init(_ style: BoxStyle, model: ButtonModel, animation: ButtonAnimation?, @ChildrenBuilder content: () -> [any View]) {
        self.boxStyle = style
        self.model = model
        self.animation = animation
        self.children = content()
    }

    func makeRenderer() -> ContainerRenderer {
        TappableBoxRenderer(style: boxStyle, model: model, animation: animation)
    }
}

final class TappableBoxRenderer: ContainerRenderer {
    let style: BoxStyle
    let model: ButtonModel
    let animation: ButtonAnimation?

    init(style: BoxStyle, model: ButtonModel, animation: ButtonAnimation?) {
        self.style = style
        self.model = model
        self.animation = animation
    }

    func mount() -> PlatformView {
        let view = TappableBoxView()
        apply(to: view, animated: false)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? TappableBoxView else { return }
        apply(to: view, animated: true)
    }

    private func apply(to view: TappableBoxView, animated: Bool) {
        let applyBlock = {
            view.sizing = self.style.frame
            view.shape = self.style.shape
            view.surface = self.style.surface
            view.clip = self.style.clip
            view.padding = self.style.padding
            view.alignment = self.style.alignment
            view.overflow = self.style.overflow
            view.setNeedsDisplay()
        }

        if animated, let anim = animation, anim.duration > 0 {
            UIView.animate(withDuration: anim.duration, delay: 0, options: anim.uiViewAnimationOptions) {
                applyBlock()
                view.layoutIfNeeded()
            }
        } else {
            applyBlock()
        }

        view.buttonModel = model
        view.accessibilityLabel = model.view.label
        view.isUserInteractionEnabled = true
        view.updateAccessibility()
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - TappableBoxView

final class TappableBoxView: BoxView {
    weak var buttonModel: ButtonModel?

    func updateAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        if buttonModel?.isDisabled == true {
            accessibilityTraits.insert(.notEnabled)
        }
        if buttonModel?.currentState.contains(.selected) == true {
            accessibilityTraits.insert(.selected)
        }
    }

    override func accessibilityActivate() -> Bool {
        buttonModel?.onTap?()
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        buttonModel?.handlePress()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let inside = touches.first.map { bounds.contains($0.location(in: self)) } ?? false
        buttonModel?.handleRelease(inside: inside)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        buttonModel?.handleRelease(inside: false)
    }
}

#endif
