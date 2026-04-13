#if canImport(UIKit)
import UIKit

// MARK: - TextField<T>

/// Generic text input. Parser converts text→T, formatter converts T→text.
/// Transformer modifies display text without affecting the underlying value.
/// Filter blocks invalid input. Validator returns an error string or nil.
public struct TextField<T>: ModelView {
    public let value: Binding<T>
    public let parser: (String) -> T?
    public let formatter: (T) -> String
    public let transformer: ((String) -> String)?
    public let filter: ((String) -> Bool)?
    public let validator: ((T) -> String?)?
    public let decoration: TextFieldDecoration
    public let keyboard: KeyboardConfig
    public let style: StateProperty<TextFieldStyle>
    public let onChanged: ((T) -> Void)?
    public let onSubmit: (@MainActor () -> Void)?

    public init(
        value: Binding<T>,
        parser: @escaping (String) -> T?,
        formatter: @escaping (T) -> String,
        transformer: ((String) -> String)? = nil,
        filter: ((String) -> Bool)? = nil,
        validator: ((T) -> String?)? = nil,
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()),
        onChanged: ((T) -> Void)? = nil,
        onSubmit: (@MainActor () -> Void)? = nil
    ) {
        self.value = value; self.parser = parser; self.formatter = formatter
        self.transformer = transformer; self.filter = filter; self.validator = validator
        self.decoration = decoration; self.keyboard = keyboard; self.style = style
        self.onChanged = onChanged; self.onSubmit = onSubmit
    }

    public func makeModel(context: BuildContext) -> TextFieldModel<T> { TextFieldModel() }
    public func makeBuilder() -> TextFieldBuilder<T> { TextFieldBuilder() }
}

// MARK: - String convenience

public extension TextField where T == String {
    init(
        text: Binding<String>,
        transformer: ((String) -> String)? = nil,
        filter: ((String) -> Bool)? = nil,
        validator: ((String) -> String?)? = nil,
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()),
        onChanged: ((String) -> Void)? = nil,
        onSubmit: (@MainActor () -> Void)? = nil
    ) {
        self.init(value: text, parser: { $0 }, formatter: { $0 },
                  transformer: transformer, filter: filter, validator: validator,
                  decoration: decoration, keyboard: keyboard, style: style,
                  onChanged: onChanged, onSubmit: onSubmit)
    }
}

// MARK: - Decoration

public struct TextFieldDecoration {
    public var placeholder: String?
    public var label: String?
    public var labelPosition: LabelPosition
    public var helper: String?
    public var error: String?
    public var obscureCharacter: Character
    public var leading: (any View)?
    public var trailing: (any View)?
    public var lines: ClosedRange<Int>
    public var alignment: TextAlign

    public init(
        placeholder: String? = nil,
        label: String? = nil,
        labelPosition: LabelPosition = .above,
        helper: String? = nil,
        error: String? = nil,
        obscureCharacter: Character = "•",
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        lines: ClosedRange<Int> = 1...1,
        alignment: TextAlign = .leading
    ) {
        self.placeholder = placeholder; self.label = label
        self.labelPosition = labelPosition; self.helper = helper
        self.error = error; self.obscureCharacter = obscureCharacter
        self.leading = leading; self.trailing = trailing
        self.lines = lines; self.alignment = alignment
    }
}

public enum LabelPosition: Sendable {
    case above
    case inside
    case border
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

    public init(
        field: BoxStyle = BoxStyle(.fillWidth.height(.fix(48)), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8), padding: Padding(horizontal: 12)),
        text: TextStyle = TextStyle(font: Font(size: 16)),
        placeholder: TextStyle = TextStyle(font: Font(size: 16), color: .gray),
        label: TextStyle = TextStyle(font: Font(size: 14, weight: 500)),
        helper: TextStyle = TextStyle(font: Font(size: 12), color: .gray),
        error: TextStyle = TextStyle(font: Font(size: 12), color: .red)
    ) {
        self.field = field; self.text = text; self.placeholder = placeholder
        self.label = label; self.helper = helper; self.error = error
    }
}

// MARK: - Mask

enum TextMask {
    /// Apply mask: # = digit, A = letter, * = any, others = literal
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

    static func strip(_ mask: String, from text: String) -> String {
        let literals = Set(mask.filter { $0 != "#" && $0 != "A" && $0 != "*" })
        return String(text.filter { !literals.contains($0) })
    }

    static func obscure(_ text: String, with char: Character) -> String {
        String(repeating: char, count: text.count)
    }
}

// MARK: - Model

public final class TextFieldModel<T>: ViewModel<TextField<T>> {
    var isFocused = false
    var error: String?
    var displayText: String = ""

    public override func didInit() {
        displayText = view.formatter(view.value.value)
        validate()
    }

    public override func didUpdate(from oldView: TextField<T>) {
        displayText = view.formatter(view.value.value)
        validate()
    }

    var currentState: UIState {
        var state: UIState = .idle
        if isFocused { state.insert(.focused) }
        if !displayText.isEmpty { state.insert(.selected) }
        return state
    }

    func textChanged(_ newText: String) {
        if let filter = view.filter, !filter(newText) { return }
        guard let parsed = view.parser(newText) else { return }
        view.value.value = parsed
        displayText = view.formatter(parsed)
        validate()
        view.onChanged?(parsed)
        node?.markDirty()
    }

    func validate() {
        if let validator = view.validator {
            error = validator(view.value.value)
        } else {
            error = view.decoration.error
        }
    }

    func focusChanged(_ focused: Bool) {
        rebuild { isFocused = focused }
    }

    func submit() {
        view.onSubmit?()
    }

    var transformedText: String {
        var text = displayText
        if let transformer = view.transformer { text = transformer(text) }
        if view.keyboard.secure { text = TextMask.obscure(text, with: view.decoration.obscureCharacter) }
        return text
    }
}

// MARK: - Builder

public final class TextFieldBuilder<T>: ViewBuilder<TextFieldModel<T>> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)
        let dec = model.view.decoration

        return Column(spacing: 4, alignment: .topLeft) {
            if dec.labelPosition == .above, let label = dec.label {
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

    func makeRenderer() -> Renderer {
        UIKitTextFieldRenderer(model: model, style: style)
    }
}

// MARK: - Renderer

final class UIKitTextFieldRenderer<T>: Renderer {
    let model: TextFieldModel<T>
    let style: TextFieldStyle

    init(model: TextFieldModel<T>, style: TextFieldStyle) {
        self.model = model; self.style = style
    }

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
        wrapper.boxFrame = style.field.frame
        wrapper.boxSurface = style.field.surface
        wrapper.boxShape = style.field.shape
        wrapper.boxPadding = style.field.padding
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
        let inset = CGRect(
            x: boxPadding.leading, y: boxPadding.top,
            width: bounds.width - boxPadding.leading - boxPadding.trailing,
            height: bounds.height - boxPadding.top - boxPadding.bottom
        )
        textField.frame = inset
    }

    func textFieldDidBeginEditing(_ textField: UITextField) { model?.focusChanged(true) }
    func textFieldDidEndEditing(_ textField: UITextField) { model?.focusChanged(false) }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        model?.submit(); textField.resignFirstResponder(); return true
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { .searchField } set {} }
}

// MARK: - Convenience Variants

public extension TextField where T == String {
    static func email(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Email"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, validator: { $0.contains("@") && $0.contains(".") ? nil : "Invalid email" },
                  decoration: decoration, keyboard: KeyboardConfig(type: .email, autocapitalization: .none), style: style)
    }

    static func password(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Password"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, decoration: decoration, keyboard: KeyboardConfig(contentType: .password, secure: true, autocapitalization: .none), style: style)
    }

    static func search(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Search"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()), onSubmit: (@MainActor () -> Void)? = nil) -> TextField {
        TextField(text: text, decoration: decoration, keyboard: KeyboardConfig(returnKey: .search), style: style, onSubmit: onSubmit)
    }

    static func masked(_ mask: String, text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, transformer: { TextMask.apply(mask, to: $0) }, decoration: decoration, style: style)
    }

    static func phone(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Phone"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        .masked("(###) ###-####", text: text, decoration: decoration, style: style)
    }
}

public extension TextField where T: Numeric & LosslessStringConvertible {
    static func number(value: Binding<T>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "0"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(value: value, parser: { T($0) }, formatter: { "\($0)" },
                  filter: { $0.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" } },
                  decoration: decoration, keyboard: KeyboardConfig(type: .decimal), style: style)
    }
}

#endif
