import Foundation

// MARK: - Button

/// A tappable component. Wraps a single child view in an interactive
/// container with state-reactive styling.
///
/// ```swift
/// Button("Submit", onTap: { })
///     .style { style, state in
///         style
///             .box(.frame(.fillWidth.height(.fix(48)))
///                 .surface(.color(.blue))
///                 .shape(.capsule()))
///             .haptic(.medium)
///     }
/// ```
public struct Button: ModelView {
    public var body: any View
    public var style: StateProperty<ButtonStyle>
    public var states: State
    public var onTap: @MainActor () -> Void
    public var debounce: Double?
    public var label: String?

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

public extension Button {
    /// Configure style as a function of the default style and current state.
    func style(_ build: @escaping @MainActor (ButtonStyle, State) -> ButtonStyle) -> Button {
        var copy = self
        copy.style = StateProperty { state in build(ButtonStyle(), state) }
        return copy
    }
}

// MARK: - ButtonStyle

@Init @Copy @Lerp
public struct ButtonStyle: Equatable {
    public var box: BoxStyle = BoxStyle()
    public var textStyle: TextStyle = TextStyle()
    @Snap public var haptic: HapticStyle = .light
    @Snap public var animation: Animation? = .default
}

// MARK: - Model

public final class ButtonModel: ViewModel<Button> {
    var isPressed = false
    var onTap: (@MainActor () -> Void)?
    var lastTapTime: Double = 0

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
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastTapTime >= debounce else { return }
            lastTapTime = now
        }
        onTap?()
    }

    func handleCancel() {
        rebuild { isPressed = false }
    }

    private func fireHaptic() {
        #if canImport(UIKit)
        let haptic = view.style(currentState).haptic
        guard haptic != .none else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch haptic {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .rigid: .rigid
        case .soft: .soft
        case .none: .light
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

// MARK: - Builder

public final class ButtonBuilder: ViewBuilder<ButtonModel> {
    public override func build(context: ViewContext) -> any View {
        let model = self.model
        let style = model.view.style(model.currentState)

        #if canImport(UIKit)
        var traits: AccessibilityTraits = .button
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
            Animated(value: style, animation: style.animation ?? .default) { _, s in
                Provided(s.textStyle) {
                    Box(s.box) { model.view.body }
                }
            }
        }
        #else
        return Animated(value: style, animation: style.animation ?? .default) { _, s in
            Provided(s.textStyle) {
                Box(s.box) { model.view.body }
            }
        }
        #endif
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

public struct ButtonTheme: Copyable {
    public var styles: [ButtonRole: ButtonStyle]
    public var chain: [ButtonRole]

    public init(_ styles: [ButtonRole: ButtonStyle], chain: [ButtonRole] = ButtonRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

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

#if canImport(UIKit)
import UIKit
#endif
