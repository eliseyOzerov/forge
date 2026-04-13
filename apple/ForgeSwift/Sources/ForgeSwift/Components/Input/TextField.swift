#if canImport(UIKit)
import UIKit

// MARK: - Function Types

public typealias TextParser<T> = Mapper<String, T?>
public typealias TextFormatter<T> = Mapper<T, String>
public typealias TextTransformer = Mapper<String, String>
public typealias InputFilter = Mapper<String, Bool>
public typealias InputValidator<T> = Mapper<T, String?>
// Handler and ValueHandler are defined in UIState.swift

// MARK: - TextField<T>

public struct TextField<T>: ModelView {
    public let value: Binding<T>
    public let logic: TextFieldLogic<T>
    public let decoration: TextFieldDecoration
    public let keyboard: KeyboardConfig
    public let style: StateProperty<TextFieldStyle>

    public init(
        value: Binding<T>,
        logic: TextFieldLogic<T>,
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) {
        self.value = value; self.logic = logic
        self.decoration = decoration; self.keyboard = keyboard; self.style = style
    }

    public func makeModel(context: BuildContext) -> TextFieldModel<T> { TextFieldModel() }
    public func makeBuilder() -> TextFieldBuilder<T> { TextFieldBuilder() }
}

// MARK: - Logic

public struct TextFieldLogic<T> {
    public var parser: TextParser<T>?
    public var formatter: TextFormatter<T>?
    public var transformer: TextTransformer?
    public var filter: InputFilter?
    public var validator: InputValidator<T>?
    public var onChanged: ValueHandler<T>?
    public var onSubmit: Handler?

    public init(
        parser: TextParser<T>? = nil,
        formatter: TextFormatter<T>? = nil,
        transformer: TextTransformer? = nil,
        filter: InputFilter? = nil,
        validator: InputValidator<T>? = nil,
        onChanged: ValueHandler<T>? = nil,
        onSubmit: Handler? = nil
    ) {
        self.parser = parser; self.formatter = formatter
        self.transformer = transformer; self.filter = filter
        self.validator = validator; self.onChanged = onChanged; self.onSubmit = onSubmit
    }
}

// MARK: - String convenience

public extension TextField where T == String {
    init(
        text: Binding<String>,
        logic: TextFieldLogic<String> = TextFieldLogic(),
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) {
        self.init(value: text, logic: logic, decoration: decoration, keyboard: keyboard, style: style)
    }
}

// MARK: - Decoration

public struct TextFieldDecoration {
    public var placeholder: String?
    public var label: String?
    public var helper: String?
    public var error: String?
    public var leading: (any View)?
    public var trailing: (any View)?
    public var lines: ClosedRange<Int>
    public var alignment: TextAlign

    public init(
        placeholder: String? = nil,
        label: String? = nil,
        helper: String? = nil,
        error: String? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        lines: ClosedRange<Int> = 1...1,
        alignment: TextAlign = .leading
    ) {
        self.placeholder = placeholder; self.label = label
        self.helper = helper; self.error = error
        self.leading = leading; self.trailing = trailing
        self.lines = lines; self.alignment = alignment
    }
}

// MARK: - Keyboard Config

public struct KeyboardConfig: Sendable {
    public var type: KeyboardType
    public var contentType: ContentType?
    public var secure: Bool
    public var autocapitalization: Autocapitalization
    public var returnKey: ReturnKey

    public init(
        type: KeyboardType = .default,
        contentType: ContentType? = nil,
        secure: Bool = false,
        autocapitalization: Autocapitalization = .sentences,
        returnKey: ReturnKey = .default
    ) {
        self.type = type; self.contentType = contentType
        self.secure = secure; self.autocapitalization = autocapitalization
        self.returnKey = returnKey
    }
}

public enum KeyboardType: Sendable {
    case `default`, email, number, decimal, phone, url
    var ui: UIKeyboardType {
        switch self {
        case .default: .default; case .email: .emailAddress
        case .number: .numberPad; case .decimal: .decimalPad
        case .phone: .phonePad; case .url: .URL
        }
    }
}

public enum ContentType: Sendable {
    case email, password, newPassword, oneTimeCode, name, username
    var ui: UITextContentType {
        switch self {
        case .email: .emailAddress; case .password: .password
        case .newPassword: .newPassword; case .oneTimeCode: .oneTimeCode
        case .name: .name; case .username: .username
        }
    }
}

public enum Autocapitalization: Sendable {
    case none, words, sentences, all
    var ui: UITextAutocapitalizationType {
        switch self {
        case .none: .none; case .words: .words
        case .sentences: .sentences; case .all: .allCharacters
        }
    }
}

public enum ReturnKey: Sendable {
    case `default`, done, next, search, go, send
    var ui: UIReturnKeyType {
        switch self {
        case .default: .default; case .done: .done
        case .next: .next; case .search: .search
        case .go: .go; case .send: .send
        }
    }
}

// MARK: - Style

public struct TextFieldStyle {
    public var field: BoxStyle
    public var text: TextStyle
    public var placeholder: TextStyle
    public var label: TextStyle
    public var helper: TextStyle
    public var error: TextStyle
    public var labelPosition: LabelPosition
    public var obscureCharacter: Character

    public init(
        field: BoxStyle = BoxStyle(.fillWidth.height(.fix(48)), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8), padding: Padding(horizontal: 12)),
        text: TextStyle = TextStyle(font: Font(size: 16)),
        placeholder: TextStyle = TextStyle(font: Font(size: 16), color: .gray),
        label: TextStyle = TextStyle(font: Font(size: 14, weight: 500)),
        helper: TextStyle = TextStyle(font: Font(size: 12), color: .gray),
        error: TextStyle = TextStyle(font: Font(size: 12), color: .red),
        labelPosition: LabelPosition = .above,
        obscureCharacter: Character = "•"
    ) {
        self.field = field; self.text = text; self.placeholder = placeholder
        self.label = label; self.helper = helper; self.error = error
        self.labelPosition = labelPosition; self.obscureCharacter = obscureCharacter
    }
}

public enum LabelPosition: Sendable {
    case above
    case inside
    case border
}

// MARK: - TextMask

enum TextMask {
    static func apply(_ mask: String, to text: String) -> String {
        var result = ""; var textIdx = text.startIndex
        for char in mask {
            guard textIdx < text.endIndex else { break }
            switch char {
            case "#" where text[textIdx].isNumber:
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "A" where text[textIdx].isLetter:
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "*":
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "#", "A": break
            default: result.append(char)
            }
        }
        return result
    }

    static func obscure(_ text: String, with char: Character) -> String {
        String(repeating: char, count: text.count)
    }
}

// MARK: - PasswordStrength

public enum PasswordStrength {
    case weak, fair, strong, veryStrong

    var message: String? {
        switch self {
        case .weak: "Weak password"
        case .fair: nil
        case .strong: nil
        case .veryStrong: nil
        }
    }

    public static func evaluate(_ password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }
        switch score {
        case 0...1: return .weak
        case 2: return .fair
        case 3...4: return .strong
        default: return .veryStrong
        }
    }
}

// MARK: - Model

public final class TextFieldModel<T>: ViewModel<TextField<T>> {
    var isFocused = false
    var error: String?
    var displayText: String = ""

    public override func didInit() {
        displayText = format(view.value.value)
        validate()
    }

    public override func didUpdate(from oldView: TextField<T>) {
        displayText = format(view.value.value)
        validate()
    }

    private func format(_ value: T) -> String {
        view.logic.formatter?(value) ?? "\(value)"
    }

    private func parse(_ text: String) -> T? {
        if let parser = view.logic.parser { return parser(text) }
        return text as? T
    }

    var currentState: UIState {
        var state: UIState = .idle
        if isFocused { state.insert(.focused) }
        if !displayText.isEmpty { state.insert(.selected) }
        return state
    }

    func textChanged(_ newText: String) {
        if let filter = view.logic.filter, !filter(newText) { return }
        guard let parsed = parse(newText) else { return }
        view.value.value = parsed
        displayText = format(parsed)
        validate()
        view.logic.onChanged?(parsed)
        node?.markDirty()
    }

    func validate() {
        error = view.logic.validator?(view.value.value) ?? view.decoration.error
    }

    func focusChanged(_ focused: Bool) {
        rebuild { isFocused = focused }
    }

    func submit() {
        view.logic.onSubmit?()
    }

    var transformedText: String {
        var text = displayText
        if let transformer = view.logic.transformer { text = transformer(text) }
        let style = view.style(currentState)
        if view.keyboard.secure { text = TextMask.obscure(text, with: style.obscureCharacter) }
        return text
    }
}

// MARK: - Builder

public final class TextFieldBuilder<T>: ViewBuilder<TextFieldModel<T>> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)
        let dec = model.view.decoration

        return Column(spacing: 4, alignment: .topLeft) {
            if style.labelPosition == .above, let label = dec.label {
                Text(label, style: style.label)
            }
            TextFieldLeaf(model: model, style: style)
            if let error = model.error {
                Text(error, style: style.error)
            } else if let helper = dec.helper {
                Text(helper, style: style.helper)
            }
        }
    }
}

// MARK: - Leaf

struct TextFieldLeaf<T>: LeafView {
    let model: TextFieldModel<T>
    let style: TextFieldStyle
    func makeRenderer() -> Renderer { UIKitTextFieldRenderer(model: model, style: style) }
}

// MARK: - Renderer

final class UIKitTextFieldRenderer<T>: Renderer {
    let model: TextFieldModel<T>
    let style: TextFieldStyle

    init(model: TextFieldModel<T>, style: TextFieldStyle) { self.model = model; self.style = style }

    func mount() -> PlatformView {
        let wrapper = TextFieldWrapperView<T>()
        apply(to: wrapper)
        return wrapper
    }

    func update(_ platformView: PlatformView) {
        guard let wrapper = platformView as? TextFieldWrapperView<T> else { return }
        apply(to: wrapper)
    }

    private func apply(to wrapper: TextFieldWrapperView<T>) {
        let field = wrapper.textField
        let kb = model.view.keyboard
        let dec = model.view.decoration

        field.text = model.isFocused ? model.displayText : model.transformedText
        field.placeholder = dec.placeholder
        field.isSecureTextEntry = kb.secure
        field.keyboardType = kb.type.ui
        field.autocapitalizationType = kb.autocapitalization.ui
        field.returnKeyType = kb.returnKey.ui
        field.textAlignment = dec.alignment.nsTextAlignment
        if let ct = kb.contentType { field.textContentType = ct.ui }
        field.font = style.text.font.resolvedFont

        wrapper.model = model
        wrapper.sizing = style.field.frame
        wrapper.surface = style.field.surface
        wrapper.shape = style.field.shape
        wrapper.padding = style.field.padding
        wrapper.invalidateIntrinsicContentSize()
        wrapper.setNeedsDisplay()
    }
}

// MARK: - Wrapper View

final class TextFieldWrapperView<T>: BoxView, UITextFieldDelegate {
    let textField = UITextField()
    weak var model: TextFieldModel<T>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        textField.delegate = self
        textField.borderStyle = .none
        addSubview(textField)
        textField.addAction(UIAction { [weak self] _ in
            self?.model?.textChanged(self?.textField.text ?? "")
        }, for: .editingChanged)
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

    func textFieldDidBeginEditing(_ textField: UITextField) {
        model?.focusChanged(true)
        scrollIntoViewIfNeeded()
    }
    func textFieldDidEndEditing(_ textField: UITextField) { model?.focusChanged(false) }

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
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        model?.submit(); textField.resignFirstResponder(); return true
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            var traits: UIAccessibilityTraits = [.none]
            if model?.view.keyboard.secure == true { traits.insert(.keyboardKey) }
            return traits
        }
        set {}
    }
    override var accessibilityLabel: String? {
        get { model?.view.decoration.label ?? model?.view.decoration.placeholder }
        set {}
    }
}

// MARK: - Convenience Variants

public extension TextField where T == String {
    static func email(
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "you@example.com", label: "Email"),
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            validator: InputValidator {
                guard !$0.isEmpty else { return nil }
                return $0.contains("@") && $0.contains(".") ? nil : "Invalid email"
            },
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(type: .email, contentType: .email, autocapitalization: .none), style: style)
    }

    static func password(
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Enter password", label: "Password"),
        showStrength: Bool = false,
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            validator: showStrength ? InputValidator { PasswordStrength.evaluate($0).message } : nil,
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(contentType: .password, secure: true, autocapitalization: .none), style: style)
    }

    static func name(
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Full name", label: "Name"),
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(contentType: .name, autocapitalization: .words), style: style)
    }

    static func search(
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Search"),
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(returnKey: .search), style: style)
    }

    static func phone(
        text: Binding<String>,
        mask: String = "(###) ###-####",
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "(555) 555-5555", label: "Phone"),
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            transformer: TextTransformer { TextMask.apply(mask, to: $0) },
            filter: InputFilter { $0.allSatisfy { $0.isNumber } },
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(type: .phone), style: style)
    }

    static func masked(
        _ mask: String,
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(),
        onChanged: ValueHandler<String>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            transformer: TextTransformer { TextMask.apply(mask, to: $0) },
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: TextFieldDecoration(
            placeholder: decoration.placeholder ?? mask,
            label: decoration.label,
            helper: decoration.helper,
            error: decoration.error,
            leading: decoration.leading,
            trailing: decoration.trailing,
            lines: decoration.lines,
            alignment: decoration.alignment
        ), style: style)
    }

    static func multiline(
        text: Binding<String>,
        decoration: TextFieldDecoration = TextFieldDecoration(),
        lines: ClosedRange<Int> = 3...10,
        onChanged: ValueHandler<String>? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle(
            field: BoxStyle(.fillWidth.height(.hug(min: 80)), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8), padding: Padding(all: 12))
        ))
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            onChanged: onChanged
        ), decoration: TextFieldDecoration(
            placeholder: decoration.placeholder,
            label: decoration.label,
            helper: decoration.helper,
            error: decoration.error,
            leading: decoration.leading,
            trailing: decoration.trailing,
            lines: lines,
            alignment: decoration.alignment
        ), style: style)
    }
}

public extension TextField where T: Numeric & LosslessStringConvertible {
    static func number(
        value: Binding<T>,
        decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "0"),
        allowDecimal: Bool = true,
        allowNegative: Bool = true,
        onChanged: ValueHandler<T>? = nil,
        onSubmit: Handler? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(value: value, logic: TextFieldLogic(
            parser: TextParser { T($0) }, formatter: TextFormatter { "\($0)" },
            filter: InputFilter { text in
                text.allSatisfy { c in
                    c.isNumber
                    || (allowDecimal && c == ".")
                    || (allowNegative && c == "-")
                }
            },
            onChanged: onChanged,
            onSubmit: onSubmit
        ), decoration: decoration,
           keyboard: KeyboardConfig(type: allowDecimal ? .decimal : .number), style: style)
    }
}

#endif
