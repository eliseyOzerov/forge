#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class TextFieldTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(
        text: String = "",
        logic: TextFieldLogic<String> = TextFieldLogic(),
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: StateProperty<TextFieldStyle> = .constant(TextFieldStyle())
    ) -> TextFieldModel<String> {
        let binding = Binding( text)
        let field = TextField(text: binding, logic: logic, decoration: decoration, keyboard: keyboard, style: style)
        let context = BuildContext(node: BuiltNode())
        let model = TextFieldModel<String>(context: context)
        model.didInit(view: field)
        return model
    }

    // MARK: - TextMask

    func testMaskPhoneNumber() {
        let result = TextMask.apply("(###) ###-####", to: "5551234567")
        XCTAssertEqual(result, "(555) 123-4567")
    }

    func testMaskPartialInput() {
        let result = TextMask.apply("(###) ###-####", to: "555")
        // Mask only emits literals when there's a next digit to consume
        XCTAssertEqual(result, "(555")
    }

    func testMaskEmptyInput() {
        let result = TextMask.apply("(###) ###-####", to: "")
        XCTAssertEqual(result, "")
    }

    func testMaskLetterSlots() {
        let result = TextMask.apply("AA-###", to: "AB123")
        XCTAssertEqual(result, "AB-123")
    }

    func testMaskWildcard() {
        let result = TextMask.apply("***-***", to: "A1b2C3")
        XCTAssertEqual(result, "A1b-2C3")
    }

    func testMaskFiltersMismatch() {
        // # expects number, A doesn't match → mask stops advancing
        let result = TextMask.apply("###", to: "A1B")
        XCTAssertEqual(result, "")
    }

    func testObscureText() {
        XCTAssertEqual(TextMask.obscure("hello", with: "•"), "•••••")
    }

    func testObscureEmpty() {
        XCTAssertEqual(TextMask.obscure("", with: "•"), "")
    }

    func testObscureCustomChar() {
        XCTAssertEqual(TextMask.obscure("abc", with: "*"), "***")
    }

    // MARK: - PasswordStrength

    func testPasswordStrengthWeak() {
        XCTAssertEqual(PasswordStrength.evaluate("abc"), .weak)
    }

    func testPasswordStrengthFair() {
        // Score 2: length≥8 (+1) + has uppercase (+1) = fair
        XCTAssertEqual(PasswordStrength.evaluate("Abcdefgh"), .fair)
    }

    func testPasswordStrengthStrong() {
        XCTAssertEqual(PasswordStrength.evaluate("Abcdefgh1"), .strong)
    }

    func testPasswordStrengthVeryStrong() {
        XCTAssertEqual(PasswordStrength.evaluate("Abcdefghijk1!"), .veryStrong)
    }

    func testPasswordStrengthEmpty() {
        XCTAssertEqual(PasswordStrength.evaluate(""), .weak)
    }

    func testPasswordStrengthWeakMessage() {
        XCTAssertNotNil(PasswordStrength.weak.message)
    }

    func testPasswordStrengthStrongNoMessage() {
        XCTAssertNil(PasswordStrength.strong.message)
    }

    // MARK: - Config Defaults

    func testKeyboardConfigDefaults() {
        let config = KeyboardConfig()
        XCTAssertFalse(config.secure)
        XCTAssertNil(config.contentType)
    }

    func testTextFieldDecorationDefaults() {
        let dec = TextFieldDecoration()
        XCTAssertNil(dec.placeholder)
        XCTAssertNil(dec.label)
        XCTAssertNil(dec.helper)
        XCTAssertNil(dec.error)
        XCTAssertNil(dec.leading)
        XCTAssertNil(dec.trailing)
        XCTAssertEqual(dec.lines, 1...1)
    }

    func testTextFieldStyleDefaults() {
        let style = TextFieldStyle()
        XCTAssertEqual(style.obscureCharacter, "•")
        XCTAssertEqual(style.labelPosition, .above)
    }

    // MARK: - Model: currentState

    func testModelDefaultStateIsIdle() {
        let model = makeModel()
        XCTAssertTrue(model.currentState.contains(.idle))
        XCTAssertFalse(model.currentState.contains(.focused))
    }

    func testModelFocusedState() {
        let model = makeModel()
        model.focusChanged(true)
        XCTAssertTrue(model.currentState.contains(.focused))
    }

    func testModelUnfocusedState() {
        let model = makeModel()
        model.focusChanged(true)
        model.focusChanged(false)
        XCTAssertFalse(model.currentState.contains(.focused))
    }

    func testModelSelectedWhenNotEmpty() {
        let model = makeModel(text: "hello")
        XCTAssertTrue(model.currentState.contains(.selected))
    }

    func testModelNotSelectedWhenEmpty() {
        let model = makeModel(text: "")
        XCTAssertFalse(model.currentState.contains(.selected))
    }

    // MARK: - Model: textChanged pipeline

    func testTextChangedUpdatesDisplayText() {
        let model = makeModel()
        model.textChanged("hello")
        XCTAssertEqual(model.displayText, "hello")
    }

    func testTextChangedFiresOnChanged() {
        var changed: String?
        let model = makeModel(logic: TextFieldLogic(
            onChanged: { changed = $0 }
        ))
        model.textChanged("hello")
        XCTAssertEqual(changed, "hello")
    }

    func testTextChangedFilterBlocks() {
        let model = makeModel(logic: TextFieldLogic(
            filter: InputFilter { $0.allSatisfy { $0.isNumber } }
        ))
        model.textChanged("abc")
        XCTAssertEqual(model.displayText, "") // filtered out
    }

    func testTextChangedFilterAllows() {
        let model = makeModel(logic: TextFieldLogic(
            filter: InputFilter { $0.allSatisfy { $0.isNumber } }
        ))
        model.textChanged("123")
        XCTAssertEqual(model.displayText, "123")
    }

    func testTextChangedWithFormatter() {
        let model = makeModel(logic: TextFieldLogic(
            formatter: TextFormatter { $0.uppercased() }
        ))
        model.textChanged("hello")
        XCTAssertEqual(model.displayText, "HELLO")
    }

    func testTextChangedWithValidator() {
        let model = makeModel(logic: TextFieldLogic(
            validator: InputValidator { $0.isEmpty ? "Required" : nil }
        ))
        model.textChanged("")
        XCTAssertEqual(model.error, "Required")
        model.textChanged("hi")
        XCTAssertNil(model.error)
    }

    // MARK: - Model: transformedText

    func testTransformedTextWithTransformer() {
        let model = makeModel(logic: TextFieldLogic(
            transformer: TextTransformer { $0.uppercased() }
        ))
        model.textChanged("hello")
        XCTAssertEqual(model.transformedText, "HELLO")
    }

    func testTransformedTextSecure() {
        let model = makeModel(keyboard: KeyboardConfig(secure: true))
        model.textChanged("secret")
        XCTAssertEqual(model.transformedText, "••••••")
    }

    func testTransformedTextSecureCustomChar() {
        let style = TextFieldStyle(obscureCharacter: "*")
        let model = makeModel(keyboard: KeyboardConfig(secure: true), style: .constant(style))
        model.textChanged("abc")
        XCTAssertEqual(model.transformedText, "***")
    }

    // MARK: - Model: submit

    func testSubmitFiresOnSubmit() {
        var submitted = false
        let model = makeModel(logic: TextFieldLogic(
            onSubmit: { submitted = true }
        ))
        model.submit()
        XCTAssertTrue(submitted)
    }

    // MARK: - Renderer: mount

    private func mountField(
        text: String = "",
        decoration: TextFieldDecoration = TextFieldDecoration(),
        keyboard: KeyboardConfig = KeyboardConfig(),
        style: TextFieldStyle = TextFieldStyle()
    ) -> TextFieldWrapperView<String> {
        let binding = Binding(text)
        let field = TextField(text: binding, decoration: decoration, keyboard: keyboard, style: .constant(style))
        let context = BuildContext(node: BuiltNode())
        let model = TextFieldModel<String>(context: context)
        model.didInit(view: field)
        let renderer = UIKitTextFieldRenderer(model: model, style: style)
        return renderer.mount() as! TextFieldWrapperView<String>
    }

    func testMountProducesWrapperView() {
        let wrapper = mountField()
        XCTAssertTrue(wrapper is BoxView)
    }

    func testMountSetsPlaceholder() {
        let wrapper = mountField(decoration: TextFieldDecoration(placeholder: "Enter text"))
        XCTAssertEqual(wrapper.textField.placeholder, "Enter text")
    }

    func testMountSetsKeyboardType() {
        let wrapper = mountField(keyboard: KeyboardConfig(type: .email))
        XCTAssertTrue(wrapper.textField.keyboardType == .emailAddress)
    }

    func testMountSetsSecureEntry() {
        let wrapper = mountField(keyboard: KeyboardConfig(secure: true))
        XCTAssertTrue(wrapper.textField.isSecureTextEntry)
    }

    func testMountSetsReturnKey() {
        let wrapper = mountField(keyboard: KeyboardConfig(returnKey: .search))
        XCTAssertTrue(wrapper.textField.returnKeyType == .search)
    }

    // MARK: - Convenience Factories

    func testEmailFactory() {
        let binding = Binding("")
        let field = TextField<String>.email(text: binding)
        XCTAssertTrue(field.keyboard.type == .email)
        XCTAssertTrue(field.keyboard.contentType == .email)
        XCTAssertTrue(field.keyboard.autocapitalization == .none)
    }

    func testPasswordFactory() {
        let binding = Binding("")
        let field = TextField<String>.password(text: binding)
        XCTAssertTrue(field.keyboard.secure)
        XCTAssertTrue(field.keyboard.contentType == .password)
        XCTAssertTrue(field.keyboard.autocapitalization == .none)
    }

    func testNameFactory() {
        let binding = Binding("")
        let field = TextField<String>.name(text: binding)
        XCTAssertTrue(field.keyboard.contentType == .name)
        XCTAssertTrue(field.keyboard.autocapitalization == .words)
    }

    func testSearchFactory() {
        let binding = Binding("")
        let field = TextField<String>.search(text: binding)
        XCTAssertTrue(field.keyboard.returnKey == .search)
    }

    func testPhoneFactory() {
        let binding = Binding("")
        let field = TextField<String>.phone(text: binding)
        XCTAssertTrue(field.keyboard.type == .phone)
        XCTAssertNotNil(field.logic.transformer)
        XCTAssertNotNil(field.logic.filter)
    }

    func testNumberFactory() {
        let binding = Binding(0)
        let field = TextField<Int>.number(value: binding)
        XCTAssertNotNil(field.logic.parser)
        XCTAssertNotNil(field.logic.formatter)
        XCTAssertNotNil(field.logic.filter)
    }

    // MARK: - Enum UIKit mappings

    func testKeyboardTypeMappings() {
        XCTAssertTrue(KeyboardType.email.ui == .emailAddress)
        XCTAssertTrue(KeyboardType.number.ui == .numberPad)
        XCTAssertTrue(KeyboardType.decimal.ui == .decimalPad)
        XCTAssertTrue(KeyboardType.phone.ui == .phonePad)
        XCTAssertTrue(KeyboardType.url.ui == .URL)
    }

    func testContentTypeMappings() {
        XCTAssertTrue(ContentType.email.ui == .emailAddress)
        XCTAssertTrue(ContentType.password.ui == .password)
        XCTAssertTrue(ContentType.newPassword.ui == .newPassword)
        XCTAssertTrue(ContentType.oneTimeCode.ui == .oneTimeCode)
        XCTAssertTrue(ContentType.name.ui == .name)
        XCTAssertTrue(ContentType.username.ui == .username)
    }

    func testReturnKeyMappings() {
        XCTAssertTrue(ReturnKey.done.ui == .done)
        XCTAssertTrue(ReturnKey.next.ui == .next)
        XCTAssertTrue(ReturnKey.search.ui == .search)
        XCTAssertTrue(ReturnKey.go.ui == .go)
        XCTAssertTrue(ReturnKey.send.ui == .send)
    }

    func testAutocapitalizationMappings() {
        XCTAssertTrue(Autocapitalization.none.ui == .none)
        XCTAssertTrue(Autocapitalization.words.ui == .words)
        XCTAssertTrue(Autocapitalization.sentences.ui == .sentences)
        XCTAssertTrue(Autocapitalization.all.ui == .allCharacters)
    }
}

#endif
