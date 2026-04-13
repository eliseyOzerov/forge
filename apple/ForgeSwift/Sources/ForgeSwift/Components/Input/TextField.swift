#if canImport(UIKit)
import UIKit

// MARK: - Function Types

public typealias TextParser<T> = Mapper<String, T?>
public typealias TextFormatter<T> = Mapper<T, String>
public typealias TextTransformer = Mapper<String, String>
public typealias InputFilter = Mapper<String, Bool>
public typealias InputValidator<T> = Mapper<T, String?>
public typealias Handler = @MainActor () -> Void
public typealias ValueHandler<T> = (T) -> Void

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

// MARK: - Mask

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

//        return Column(spacing: 4, alignment: .topLeft) {
//            if style.labelPosition == .above, let label = dec.label {
//                Text(label, style: style.label)
//            }
//            TextFieldLeaf(model: model, style: style)
//            if let error = model.error {
//                Text(error, style: style.error)
//            } else if let helper = dec.helper {
//                Text(helper, style: style.helper)
//            }
//        }
        return TextFieldLeaf(model: model, style: style)
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
        TextField(text: text, logic: TextFieldLogic(
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
            validator: InputValidator { $0.contains("@") && $0.contains(".") ? nil : "Invalid email" }
        ), decoration: decoration, keyboard: KeyboardConfig(type: .email, autocapitalization: .none), style: style)
    }

    static func password(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Password"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, decoration: decoration, keyboard: KeyboardConfig(contentType: .password, secure: true, autocapitalization: .none), style: style)
    }

    static func search(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Search"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()), onSubmit: Handler? = nil) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            parser: TextParser { $0 }, formatter: TextFormatter { $0 }, onSubmit: onSubmit
        ), decoration: decoration, keyboard: KeyboardConfig(returnKey: .search), style: style)
    }

    static func masked(_ mask: String, text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
            transformer: TextTransformer { TextMask.apply(mask, to: $0) }
        ), decoration: decoration, style: style)
    }

    static func phone(text: Binding<String>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "Phone"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        .masked("(###) ###-####", text: text, decoration: decoration, style: style)
    }
}

public extension TextField where T: Numeric & LosslessStringConvertible {
    static func number(value: Binding<T>, decoration: TextFieldDecoration = TextFieldDecoration(placeholder: "0"), style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())) -> TextField {
        TextField(value: value, logic: TextFieldLogic(
            parser: TextParser { T($0) }, formatter: TextFormatter { "\($0)" },
            filter: InputFilter { $0.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" } }
        ), decoration: decoration, keyboard: KeyboardConfig(type: .decimal), style: style)
    }
}

// MARK: - EmailInput

public typealias EmailInput = TextField<String>

public extension TextField where T == String {
    static func email(
        text: Binding<String>,
        label: String? = "Email",
        placeholder: String? = "you@example.com",
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(

            validator: InputValidator {
                guard !$0.isEmpty else { return nil }
                return $0.contains("@") && $0.contains(".") ? nil : "Invalid email"
            }
        ), decoration: TextFieldDecoration(placeholder: placeholder, label: label),
           keyboard: KeyboardConfig(type: .email, contentType: .email, autocapitalization: .none), style: style)
    }
}

// MARK: - PasswordInput

public extension TextField where T == String {
    static func password(
        text: Binding<String>,
        label: String? = "Password",
        placeholder: String? = "Enter password",
        showStrength: Bool = false,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(

            validator: showStrength ? InputValidator { PasswordStrength.evaluate($0).message } : nil
        ), decoration: TextFieldDecoration(placeholder: placeholder, label: label),
           keyboard: KeyboardConfig(contentType: .password, secure: true, autocapitalization: .none), style: style)
    }
}

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

    static func evaluate(_ password: String) -> PasswordStrength {
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

// MARK: - NameInput

public extension TextField where T == String {
    static func name(
        text: Binding<String>,
        label: String? = "Name",
        placeholder: String? = "Full name",
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, decoration: TextFieldDecoration(placeholder: placeholder, label: label),
                  keyboard: KeyboardConfig(contentType: .name, autocapitalization: .words), style: style)
    }
}

// MARK: - SearchInput

public extension TextField where T == String {
    static func search(
        text: Binding<String>,
        placeholder: String? = "Search",
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()),
        onSubmit: Handler? = nil
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(
            onSubmit: onSubmit
        ), decoration: TextFieldDecoration(placeholder: placeholder),
           keyboard: KeyboardConfig(returnKey: .search), style: style)
    }
}

// MARK: - NumberInput

public extension TextField where T: Numeric & LosslessStringConvertible {
    static func number(
        value: Binding<T>,
        label: String? = nil,
        placeholder: String? = "0",
        allowDecimal: Bool = true,
        allowNegative: Bool = true,
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
            }
        ), decoration: TextFieldDecoration(placeholder: placeholder, label: label),
           keyboard: KeyboardConfig(type: allowDecimal ? .decimal : .number), style: style)
    }
}

// MARK: - PhoneInput

public extension TextField where T == String {
    static func phone(
        text: Binding<String>,
        mask: String = "(###) ###-####",
        label: String? = "Phone",
        placeholder: String? = "(555) 555-5555",
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(

            transformer: TextTransformer { TextMask.apply(mask, to: $0) },
            filter: InputFilter { $0.allSatisfy { $0.isNumber } }
        ), decoration: TextFieldDecoration(placeholder: placeholder, label: label),
           keyboard: KeyboardConfig(type: .phone), style: style)
    }
}

// MARK: - MaskedInput

public extension TextField where T == String {
    static func masked(
        _ mask: String,
        text: Binding<String>,
        label: String? = nil,
        placeholder: String? = nil,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextField {
        TextField(text: text, logic: TextFieldLogic(

            transformer: TextTransformer { TextMask.apply(mask, to: $0) }
        ), decoration: TextFieldDecoration(placeholder: placeholder ?? mask, label: label), style: style)
    }
}

// MARK: - MultilineInput

public extension TextField where T == String {
    static func multiline(
        text: Binding<String>,
        label: String? = nil,
        placeholder: String? = nil,
        lines: ClosedRange<Int> = 3...10,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle(
            field: BoxStyle(.fillWidth.height(.hug(min: 80)), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8), padding: Padding(all: 12))
        ))
    ) -> TextField {
        TextField(text: text,
                  decoration: TextFieldDecoration(placeholder: placeholder, label: label, lines: lines),
                  style: style)
    }
}

// MARK: - SplitBoxInput (OTP / PIN)

/// Individual-box-per-character input (e.g. OTP, PIN codes).
public struct SplitBoxInput: ModelView {
    public let text: Binding<String>
    public let length: Int
    public let secure: Bool
    public let style: StateProperty<BoxStyle>
    public let activeStyle: StateProperty<BoxStyle>
    public let spacing: Double

    public init(
        text: Binding<String>,
        length: Int = 6,
        secure: Bool = false,
        spacing: Double = 8,
        style: StateProperty<BoxStyle> = .constant(BoxStyle(.square(48), .color(Color(0.95, 0.95, 0.95)), .roundedRect(radius: 8))),
        activeStyle: StateProperty<BoxStyle> = .constant(BoxStyle(.square(48), .color(Color(0.9, 0.9, 1.0)).border(Color(0.2, 0.5, 1.0), width: 2), .roundedRect(radius: 8)))
    ) {
        self.text = text; self.length = length; self.secure = secure
        self.spacing = spacing; self.style = style; self.activeStyle = activeStyle
    }

    public func makeModel(context: BuildContext) -> SplitBoxModel { SplitBoxModel() }
    public func makeBuilder() -> SplitBoxBuilder { SplitBoxBuilder() }
}

public final class SplitBoxModel: ViewModel<SplitBoxInput> {
    var isFocused = false

    public override func didInit() {}

    var characters: [Character?] {
        let text = view.text.value
        return (0..<view.length).map { i in
            i < text.count ? text[text.index(text.startIndex, offsetBy: i)] : nil
        }
    }

    var activeIndex: Int {
        min(view.text.value.count, view.length - 1)
    }
}

public final class SplitBoxBuilder: ViewBuilder<SplitBoxModel> {
    public override func build(context: BuildContext) -> any View {
        Row(spacing: model.view.spacing) {
            for (i, char) in model.characters.enumerated() {
                let isActive = model.isFocused && i == model.activeIndex
                let boxStyle = isActive ? model.view.activeStyle(.focused) : model.view.style(.idle)
                Box(boxStyle) {
                    if let char {
                        let display = model.view.secure ? "•" : String(char)
                        Text(display, style: TextStyle(font: Font(size: 20, weight: 600), align: .center))
                    }
                }
            }
        }
    }
}

// MARK: - TokenInput

/// Multi-value input where each value becomes a removable chip.
public struct TokenInput: ModelView {
    public let values: Binding<[String]>
    public let separators: Set<Character>
    public let placeholder: String?
    public let style: StateProperty<TextFieldStyle>
    public let chipStyle: BoxStyle

    public init(
        values: Binding<[String]>,
        separators: Set<Character> = [",", " "],
        placeholder: String? = "Add tags...",
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle()),
        chipStyle: BoxStyle = BoxStyle(.hug, .color(Color(0.9, 0.9, 0.95)), .capsule(), padding: Padding(horizontal: 10, vertical: 4))
    ) {
        self.values = values; self.separators = separators
        self.placeholder = placeholder; self.style = style; self.chipStyle = chipStyle
    }

    public func makeModel(context: BuildContext) -> TokenInputModel { TokenInputModel() }
    public func makeBuilder() -> TokenInputBuilder { TokenInputBuilder() }
}

public final class TokenInputModel: ViewModel<TokenInput> {
    var inputText = ""
    public override func didInit() {}

    func addToken() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        rebuild {
            view.values.value.append(trimmed)
            inputText = ""
        }
    }

    func removeToken(at index: Int) {
        rebuild { view.values.value.remove(at: index) }
    }

    func textChanged(_ text: String) {
        if let last = text.last, view.separators.contains(last) {
            inputText = String(text.dropLast())
            addToken()
        } else {
            inputText = text
            node?.markDirty()
        }
    }
}

public final class TokenInputBuilder: ViewBuilder<TokenInputModel> {
    public override func build(context: BuildContext) -> any View {
        Column(spacing: 8, alignment: .topLeft) {
            Row(spacing: 4, lineSpacing: 4, wrap: true) {
                for (i, token) in model.view.values.value.enumerated() {
                    let idx = i
                    Box(model.view.chipStyle) {
                        Row(spacing: 4) {
                            Text(token, style: TextStyle(font: Font(size: 14)))
                            Button("×", onTap: { [weak model] in model?.removeToken(at: idx) })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CreditCardInput

public struct CreditCard: Equatable {
    public var number: String
    public var expiry: String
    public var cvv: String

    public init(number: String = "", expiry: String = "", cvv: String = "") {
        self.number = number; self.expiry = expiry; self.cvv = cvv
    }

    public var isComplete: Bool {
        number.count >= 15 && expiry.count == 4 && cvv.count >= 3
    }

    public var type: CardType {
        let digits = number.prefix(2)
        guard let n = Int(digits) else { return .unknown }
        if number.hasPrefix("4") { return .visa }
        if (51...55).contains(n) { return .mastercard }
        if number.hasPrefix("34") || number.hasPrefix("37") { return .amex }
        if number.hasPrefix("6011") || number.hasPrefix("65") { return .discover }
        return .unknown
    }

    public var formattedNumber: String {
        let groupSize = type == .amex ? [4, 6, 5] : [4, 4, 4, 4]
        var result = ""; var idx = number.startIndex
        for (i, size) in groupSize.enumerated() {
            guard idx < number.endIndex else { break }
            if i > 0 { result.append(" ") }
            let end = number.index(idx, offsetBy: size, limitedBy: number.endIndex) ?? number.endIndex
            result.append(contentsOf: number[idx..<end])
            idx = end
        }
        return result
    }

    public var formattedExpiry: String {
        guard expiry.count >= 2 else { return expiry }
        return expiry.prefix(2) + "/" + expiry.dropFirst(2)
    }
}

public enum CardType: Sendable {
    case visa, mastercard, amex, discover, unknown

    public var name: String {
        switch self {
        case .visa: "Visa"; case .mastercard: "Mastercard"
        case .amex: "Amex"; case .discover: "Discover"; case .unknown: "Card"
        }
    }

    public var cvvLength: Int { self == .amex ? 4 : 3 }
    public var numberLength: Int { self == .amex ? 15 : 16 }
}

/// Compound credit card input: number, expiry, CVV fields.
public struct CreditCardInput: ModelView {
    public let value: Binding<CreditCard>
    public let style: StateProperty<TextFieldStyle>

    public init(
        value: Binding<CreditCard>,
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) {
        self.value = value; self.style = style
    }

    public func makeModel(context: BuildContext) -> CreditCardModel { CreditCardModel() }
    public func makeBuilder() -> CreditCardBuilder { CreditCardBuilder() }
}

public final class CreditCardModel: ViewModel<CreditCardInput> {
    var number = ""
    var expiry = ""
    var cvv = ""

    public override func didInit() {
        number = view.value.value.number
        expiry = view.value.value.expiry
        cvv = view.value.value.cvv
    }

    func updateCard() {
        view.value.value = CreditCard(number: number, expiry: expiry, cvv: cvv)
        node?.markDirty()
    }

    var cardType: CardType { view.value.value.type }
}

public final class CreditCardBuilder: ViewBuilder<CreditCardModel> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(.idle)
        let numberBinding = Binding<String>(
            get: { [weak model] in model?.number ?? "" },
            set: { [weak model] in
                let filtered = String($0.filter { $0.isNumber }.prefix(model?.cardType.numberLength ?? 16))
                model?.number = filtered
                model?.updateCard()
            }
        )
        let expiryBinding = Binding<String>(
            get: { [weak model] in model?.expiry ?? "" },
            set: { [weak model] in
                let filtered = String($0.filter { $0.isNumber }.prefix(4))
                model?.expiry = filtered
                model?.updateCard()
            }
        )
        let cvvBinding = Binding<String>(
            get: { [weak model] in model?.cvv ?? "" },
            set: { [weak model] in
                let filtered = String($0.filter { $0.isNumber }.prefix(model?.cardType.cvvLength ?? 3))
                model?.cvv = filtered
                model?.updateCard()
            }
        )

        return Column(spacing: 8) {
//            Text(model.cardType.name, style: style.label)
            
//            TextField<String>(
//                text: numberBinding,
//                logic: TextFieldLogic(
//                    transformer: TextTransformer { CreditCard(number: $0).formattedNumber },
//                    filter: InputFilter { $0.allSatisfy { $0.isNumber } }
//                ),
//                decoration: TextFieldDecoration(placeholder: "Card number"),
//                keyboard: KeyboardConfig(type: .number),
//                style: model.view.style
//            )

            Row(spacing: 8) {
                TextField<String>(
                    text: expiryBinding,
                    logic: TextFieldLogic(
                        transformer: TextTransformer { CreditCard(expiry: $0).formattedExpiry },
                        filter: InputFilter { $0.allSatisfy { $0.isNumber } }
                    ),
                    decoration: TextFieldDecoration(placeholder: "MM/YY"),
                    keyboard: KeyboardConfig(type: .number), style: model.view.style
                )

                TextField<String>(
                    text: cvvBinding,
                    logic: TextFieldLogic(filter: InputFilter { $0.allSatisfy { $0.isNumber } } ),
                    decoration: TextFieldDecoration(placeholder: "CVV"),
                    keyboard: KeyboardConfig(type: .number, secure: true), style: model.view.style
                )
            }
        }
    }
}

#endif
