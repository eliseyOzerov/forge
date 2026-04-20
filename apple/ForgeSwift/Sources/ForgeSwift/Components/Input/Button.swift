#if canImport(UIKit)
import UIKit

// MARK: - ButtonStyle

public struct ButtonStyle {
    public var box: BoxStyle
    public var textStyle: TextStyle
    public var haptic: HapticStyle
    public var animation: Animation?

    public init(
        _ box: BoxStyle = BoxStyle(),
        textStyle: TextStyle = TextStyle(),
        haptic: HapticStyle = .light,
        animation: Animation? = .default
    ) {
        self.box = box
        self.textStyle = textStyle
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
    public let states: State
    public let onTap: @MainActor () -> Void
    public let debounce: Double?
    public let label: String?

    /// Single-child button with custom content.
    public init(
        style: StateProperty<ButtonStyle> = .constant(ButtonStyle()),
        states: State = .idle,
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
        states: State = .idle,
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

    public func model(context: ViewContext) -> ButtonModel { ButtonModel(context: context) }
    public func builder(model: ButtonModel) -> ButtonBuilder { ButtonBuilder(model: model) }
}

// MARK: - Model

public final class ButtonModel: ViewModel<Button> {
    var isPressed = false
    var onTap: (@MainActor () -> Void)?
    var lastTapTime: CFTimeInterval = 0

    public override func didInit(view: Button) {
        super.didInit(view: view)
        onTap = view.onTap
    }

    public override func didUpdate(newView: Button) {
        super.didUpdate(newView: newView)
        onTap = newView.onTap
    }

    var isDisabled: Bool { view.states.contains(.disabled) }
    var isLoading: Bool { view.states.contains(.loading) }

    var currentState: State {
        var state = view.states
        if isPressed {
            state.insert(.pressed)
            state.remove(.idle)
        } else if !isDisabled {
            state.insert(.idle)
        }
        return state
    }

    func handleDown() {
        guard !isDisabled, !isLoading else { return }
        rebuild { isPressed = true }
        fireHaptic()
    }

    func handleTap() {
        guard !isDisabled, !isLoading else { return }
        rebuild { isPressed = false }
        if let debounce = view.debounce {
            let now = CACurrentMediaTime()
            guard now - lastTapTime >= debounce else { return }
            lastTapTime = now
        }
        onTap?()
    }

    func handleCancel() {
        rebuild { isPressed = false }
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
    public override func build(context: ViewContext) -> any View {
        let model = self.model
        let style = model.view.style(model.currentState)
        var traits: UIAccessibilityTraits = .button
        if model.isDisabled { traits.insert(.notEnabled) }
        return TapHandler(
            onDown: { _ in model.handleDown() },
            onEnd: { _ in model.handleTap() },
            onCancel: { model.handleCancel() },
            accessibility: AccessibilityConfig(
                traits: traits,
                label: model.view.label,
                activate: { model.handleTap(); return true }
            )
        ) {
            Provided(style.textStyle) {
                Box(style.box) { model.view.body }
            }
        }
    }
}

// MARK: - ButtonRole

public struct ButtonRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension ButtonRole {
    static let primary    = ButtonRole("primary")
    static let secondary  = ButtonRole("secondary")
    static let tertiary   = ButtonRole("tertiary")
    static let quaternary = ButtonRole("quaternary")

    static let defaultChain: [ButtonRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - ButtonTheme

/// Role-keyed ButtonStyles with cascade. Read at use sites via
/// `ctx.theme(.button).primary` (or `theme[.customRole]` for app-
/// specific roles declared as `extension ButtonRole { static let ... }`).
public struct ButtonTheme: Copyable {
    public var styles: [ButtonRole: ButtonStyle]
    public var chain: [ButtonRole]

    public init(_ styles: [ButtonRole: ButtonStyle], chain: [ButtonRole] = ButtonRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    /// Convenience init from a PriorityTokens bundle — translates
    /// the 4 built-in priority levels to matching ButtonRoles.
    public init(_ priority: PriorityTokens<ButtonStyle>) {
        var map: [ButtonRole: ButtonStyle] = [:]
        for (level, style) in priority.values {
            map[ButtonRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: ButtonStyle,
        secondary: ButtonStyle? = nil,
        tertiary: ButtonStyle? = nil,
        quaternary: ButtonStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: ButtonRole) -> ButtonStyle {
        styles.cascade(role, chain: chain) ?? ButtonStyle()
    }

    public var primary:    ButtonStyle { self[.primary] }
    public var secondary:  ButtonStyle { self[.secondary] }
    public var tertiary:   ButtonStyle { self[.tertiary] }
    public var quaternary: ButtonStyle { self[.quaternary] }

    public static func standard() -> ButtonTheme {
        ButtonTheme(primary: ButtonStyle())
    }
}

public extension ThemeSlot where T == ButtonTheme {
    static var button: ThemeSlot<ButtonTheme> { .init(ButtonTheme.self) }
}

#endif
