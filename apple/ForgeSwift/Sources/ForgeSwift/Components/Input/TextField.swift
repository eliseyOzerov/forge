#if canImport(UIKit)
import UIKit

// MARK: - TextField

/// Base text input component. Generic over the value type T —
/// parser converts text→T, formatter converts T→text.
///
/// ```swift
/// TextField(text: $name, placeholder: "Name")
///
/// TextField.email(text: $email)
/// TextField.password(text: $password)
/// TextField.number(value: $count)
/// ```
public struct TextField: ModelView {
    public let text: Binding<String>
    public let config: TextFieldConfig
    public let decoration: TextFieldDecoration
    public let style: StateProperty<TextFieldStyle>
    public let onSubmit: (@MainActor () -> Void)?

    public init(
        text: Binding<String>,
        config: TextFieldConfig = TextFieldConfig(),
        decoration: TextFieldDecoration = TextFieldDecoration(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()),
        onSubmit: (@MainActor () -> Void)? = nil
    ) {
        self.text = text
        self.config = config
        self.decoration = decoration
        self.style = style
        self.onSubmit = onSubmit
    }

    public func makeModel(context: BuildContext) -> TextFieldModel { TextFieldModel() }
    public func makeBuilder() -> TextFieldBuilder { TextFieldBuilder() }
}

// MARK: - Config

public struct TextFieldConfig {
    public var keyboard: KeyboardType
    public var contentType: ContentType?
    public var secure: Bool
    public var autocapitalization: Autocapitalization
    public var returnKey: ReturnKey
    public var multiline: Bool
    public var maxLength: Int?
    public var filter: ((String) -> Bool)?
    public var mask: String?
    public var validator: ((String) -> String?)?

    public init(
        keyboard: KeyboardType = .default,
        contentType: ContentType? = nil,
        secure: Bool = false,
        autocapitalization: Autocapitalization = .sentences,
        returnKey: ReturnKey = .default,
        multiline: Bool = false,
        maxLength: Int? = nil,
        filter: ((String) -> Bool)? = nil,
        mask: String? = nil,
        validator: ((String) -> String?)? = nil
    ) {
        self.keyboard = keyboard; self.contentType = contentType
        self.secure = secure; self.autocapitalization = autocapitalization
        self.returnKey = returnKey; self.multiline = multiline
        self.maxLength = maxLength; self.filter = filter
        self.mask = mask; self.validator = validator
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

    public init(
        placeholder: String? = nil,
        label: String? = nil,
        helper: String? = nil,
        error: String? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil
    ) {
        self.placeholder = placeholder; self.label = label
        self.helper = helper; self.error = error
        self.leading = leading; self.trailing = trailing
    }
}

// MARK: - Style

public struct TextFieldStyle {
    public var field: BoxStyle
    public var textStyle: TextStyle
    public var placeholderStyle: TextStyle
    public var labelStyle: TextStyle
    public var helperStyle: TextStyle
    public var errorStyle: TextStyle

    public init(
        field: BoxStyle = BoxStyle(.fillWidth.height(.fix(48)), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8), padding: Padding(horizontal: 12)),
        textStyle: TextStyle = TextStyle(font: Font(size: 16)),
        placeholderStyle: TextStyle = TextStyle(font: Font(size: 16), color: .gray),
        labelStyle: TextStyle = TextStyle(font: Font(size: 14, weight: 500)),
        helperStyle: TextStyle = TextStyle(font: Font(size: 12), color: .gray),
        errorStyle: TextStyle = TextStyle(font: Font(size: 12), color: .red)
    ) {
        self.field = field; self.textStyle = textStyle
        self.placeholderStyle = placeholderStyle; self.labelStyle = labelStyle
        self.helperStyle = helperStyle; self.errorStyle = errorStyle
    }
}

// MARK: - Enums

public enum KeyboardType: Sendable {
    case `default`, email, number, decimal, phone, url

    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: .default; case .email: .emailAddress
        case .number: .numberPad; case .decimal: .decimalPad
        case .phone: .phonePad; case .url: .URL
        }
    }
}

public enum ContentType: Sendable {
    case email, password, newPassword, oneTimeCode, name, username

    var uiContentType: UITextContentType {
        switch self {
        case .email: .emailAddress; case .password: .password
        case .newPassword: .newPassword; case .oneTimeCode: .oneTimeCode
        case .name: .name; case .username: .username
        }
    }
}

public enum Autocapitalization: Sendable {
    case none, words, sentences, all

    var uiAutocapitalization: UITextAutocapitalizationType {
        switch self {
        case .none: .none; case .words: .words
        case .sentences: .sentences; case .all: .allCharacters
        }
    }
}

public enum ReturnKey: Sendable {
    case `default`, done, next, search, go, send

    var uiReturnKey: UIReturnKeyType {
        switch self {
        case .default: .default; case .done: .done
        case .next: .next; case .search: .search
        case .go: .go; case .send: .send
        }
    }
}

// MARK: - Masking

enum TextMask {
    static func apply(_ mask: String, to text: String) -> String {
        var result = ""
        var textIdx = text.startIndex
        for char in mask {
            guard textIdx < text.endIndex else { break }
            switch char {
            case "#" where text[textIdx].isNumber:
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "A" where text[textIdx].isLetter:
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "*":
                result.append(text[textIdx]); textIdx = text.index(after: textIdx)
            case "#", "A":
                break
            default:
                result.append(char)
            }
        }
        return result
    }

    static func strip(_ mask: String, from text: String) -> String {
        let literals = Set(mask.filter { $0 != "#" && $0 != "A" && $0 != "*" })
        return String(text.filter { !literals.contains($0) })
    }
}

// MARK: - Model

public final class TextFieldModel: ViewModel<TextField> {
    var isFocused = false
    var error: String?

    public override func didInit() {
        validate()
    }

    var currentState: UIState {
        var state: UIState = .idle
        if isFocused { state.insert(.focused) }
        if !view.text.value.isEmpty { state.insert(.selected) }
        return state
    }

    func textChanged(_ newText: String) {
        let config = view.config
        if let filter = config.filter, !filter(newText) { return }
        if let max = config.maxLength, newText.count > max { return }
        view.text.value = newText
        validate()
        node?.markDirty()
    }

    func validate() {
        error = view.config.validator?(view.text.value) ?? view.decoration.error
    }

    func focusChanged(_ focused: Bool) {
        rebuild { isFocused = focused }
    }

    func submit() {
        view.onSubmit?()
    }
}

// MARK: - Builder

public final class TextFieldBuilder: ViewBuilder<TextFieldModel> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)
        let dec = model.view.decoration

        return Column(spacing: 4, alignment: .topLeft) {
            if let label = dec.label {
                Text(label, style: style.labelStyle)
            }
            TextFieldLeaf(model: model, style: style)
            if let error = model.error {
                Text(error, style: style.errorStyle)
            } else if let helper = dec.helper {
                Text(helper, style: style.helperStyle)
            }
        }
    }
}

// MARK: - Leaf

struct TextFieldLeaf: LeafView {
    let model: TextFieldModel
    let style: TextFieldStyle

    func makeRenderer() -> Renderer {
        UIKitTextFieldRenderer(model: model, style: style)
    }
}

// MARK: - Renderer

final class UIKitTextFieldRenderer: Renderer {
    let model: TextFieldModel
    let style: TextFieldStyle

    init(model: TextFieldModel, style: TextFieldStyle) {
        self.model = model; self.style = style
    }

    func mount() -> PlatformView {
        let wrapper = TextFieldWrapper()
        apply(to: wrapper)
        return wrapper
    }

    func update(_ platformView: PlatformView) {
        guard let wrapper = platformView as? TextFieldWrapper else { return }
        apply(to: wrapper)
    }

    private func apply(to wrapper: TextFieldWrapper) {
        let field = wrapper.textField
        let config = model.view.config
        let dec = model.view.decoration

        field.text = model.view.text.value
        field.placeholder = dec.placeholder
        field.isSecureTextEntry = config.secure
        field.keyboardType = config.keyboard.uiKeyboardType
        field.autocapitalizationType = config.autocapitalization.uiAutocapitalization
        field.returnKeyType = config.returnKey.uiReturnKey
        if let contentType = config.contentType {
            field.textContentType = contentType.uiContentType
        }

        field.font = style.textStyle.font.resolvedFont

        wrapper.model = model
        wrapper.boxStyle = style.field

        wrapper.invalidateIntrinsicContentSize()
    }
}

// MARK: - TextFieldWrapper

final class TextFieldWrapper: BoxView, UITextFieldDelegate {
    let textField = UITextField()
    weak var model: TextFieldModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        textField.delegate = self
        textField.borderStyle = .none
        addSubview(textField)

        textField.addAction(UIAction { [weak self] _ in
            guard let self, let model = self.model else { return }
            model.textChanged(self.textField.text ?? "")
        }, for: .editingChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    var boxStyle: TextFieldStyle.FieldBoxStyle? {
        didSet {
            if let s = boxStyle {
                boxFrame = s.frame
                boxSurface = s.surface
                boxShape = s.shape
                boxPadding = s.padding
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = CGRect(
            x: boxPadding.leading,
            y: boxPadding.top,
            width: bounds.width - boxPadding.leading - boxPadding.trailing,
            height: bounds.height - boxPadding.top - boxPadding.bottom
        )
        textField.frame = inset
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        model?.focusChanged(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        model?.focusChanged(false)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        model?.submit()
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Convenience Constructors

public extension TextField {
    static func email(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Email"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, config: TextFieldConfig(keyboard: .email, contentType: .email, autocapitalization: .none,
            validator: { $0.contains("@") && $0.contains(".") ? nil : "Invalid email" }), decoration: decoration, style: style)
    }

    static func password(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Password"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, config: TextFieldConfig(contentType: .password, secure: true, autocapitalization: .none), decoration: decoration, style: style)
    }

    static func search(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Search"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()), onSubmit: (@MainActor () -> Void)? = nil) -> TextField {
        TextField(text: text, config: TextFieldConfig(returnKey: .search), decoration: decoration, style: style, onSubmit: onSubmit)
    }

    static func phone(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Phone"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, config: TextFieldConfig(keyboard: .phone, mask: "(###) ###-####"), decoration: decoration, style: style)
    }
}

// MARK: - Helper typealias

extension TextFieldStyle {
    typealias FieldBoxStyle = BoxStyle
}

#endif
