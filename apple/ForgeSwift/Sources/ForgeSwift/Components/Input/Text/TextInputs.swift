#if canImport(UIKit)
import UIKit

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
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
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
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
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
            parser: TextParser { $0 }, formatter: TextFormatter { $0 }, onSubmit: onSubmit
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
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
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
            parser: TextParser { $0 }, formatter: TextFormatter { $0 },
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

        return Column(spacing: 8, alignment: .topLeft) {
            Text(model.cardType.name, style: style.label)
            TextField<String>(text: numberBinding, logic: TextFieldLogic(
                parser: TextParser { $0 }, formatter: TextFormatter { $0 },
                transformer: TextTransformer { CreditCard(number: $0).formattedNumber },
                filter: InputFilter { $0.allSatisfy { $0.isNumber } }
            ), decoration: TextFieldDecoration(placeholder: "Card number"),
               keyboard: KeyboardConfig(type: .number), style: model.view.style)

            Row(spacing: 8) {
                TextField<String>(text: expiryBinding, logic: TextFieldLogic(
                    parser: TextParser { $0 }, formatter: TextFormatter { $0 },
                    transformer: TextTransformer { CreditCard(expiry: $0).formattedExpiry },
                    filter: InputFilter { $0.allSatisfy { $0.isNumber } }
                ), decoration: TextFieldDecoration(placeholder: "MM/YY"),
                   keyboard: KeyboardConfig(type: .number), style: model.view.style)

                TextField<String>(text: cvvBinding, logic: TextFieldLogic(
                    parser: TextParser { $0 }, formatter: TextFormatter { $0 },
                    filter: InputFilter { $0.allSatisfy { $0.isNumber } }
                ), decoration: TextFieldDecoration(placeholder: "CVV"),
                   keyboard: KeyboardConfig(type: .number, secure: true), style: model.view.style)
            }
        }
    }
}

#endif
