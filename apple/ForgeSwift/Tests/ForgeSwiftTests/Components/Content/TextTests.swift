#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class TextTests: XCTestCase {

    // MARK: - Helpers

    /// Extract attributes from the label's attributedText at index 0.
    private func attributes(of label: UILabel) -> [NSAttributedString.Key: Any] {
        guard let attrText = label.attributedText, attrText.length > 0 else { return [:] }
        return attrText.attributes(at: 0, effectiveRange: nil)
    }

    private func paragraphStyle(of label: UILabel) -> NSParagraphStyle? {
        attributes(of: label)[.paragraphStyle] as? NSParagraphStyle
    }

    private func mount(_ text: Text) -> UILabel {
        text.makeRenderer().mount() as! UILabel
    }

    // MARK: - 1. Data Types (pure logic)

    // TextCase

    func testTextCasePlain() {
        XCTAssertEqual(TextCase.plain.apply(to: "Hello World"), "Hello World")
    }

    func testTextCaseUppercase() {
        XCTAssertEqual(TextCase.uppercase.apply(to: "Hello World"), "HELLO WORLD")
    }

    func testTextCaseLowercase() {
        XCTAssertEqual(TextCase.lowercase.apply(to: "Hello World"), "hello world")
    }

    func testTextCaseCapitalize() {
        XCTAssertEqual(TextCase.capitalize.apply(to: "hello world"), "Hello world")
    }

    func testTextCaseTitle() {
        XCTAssertEqual(TextCase.title.apply(to: "hello world"), "Hello World")
    }

    func testTextCasePascal() {
        XCTAssertEqual(TextCase.pascal.apply(to: "hello world"), "HelloWorld")
        XCTAssertEqual(TextCase.pascal.apply(to: "some-kebab-case"), "SomeKebabCase")
        XCTAssertEqual(TextCase.pascal.apply(to: "camelCase"), "CamelCase")
    }

    func testTextCaseCamel() {
        XCTAssertEqual(TextCase.camel.apply(to: "hello world"), "helloWorld")
        XCTAssertEqual(TextCase.camel.apply(to: "PascalCase"), "pascalCase")
    }

    func testTextCaseSnake() {
        XCTAssertEqual(TextCase.snake.apply(to: "Hello World"), "hello_world")
        XCTAssertEqual(TextCase.snake.apply(to: "camelCase"), "camel_case")
    }

    func testTextCaseKebab() {
        XCTAssertEqual(TextCase.kebab.apply(to: "Hello World"), "hello-world")
        XCTAssertEqual(TextCase.kebab.apply(to: "camelCase"), "camel-case")
    }

    func testTextCaseDot() {
        XCTAssertEqual(TextCase.dot.apply(to: "Hello World"), "hello.world")
    }

    func testTextCaseSponge() {
        XCTAssertEqual(TextCase.sponge.apply(to: "hello"), "hElLo")
    }

    func testTextCaseEmptyString() {
        XCTAssertEqual(TextCase.plain.apply(to: ""), "")
        XCTAssertEqual(TextCase.uppercase.apply(to: ""), "")
        XCTAssertEqual(TextCase.lowercase.apply(to: ""), "")
        XCTAssertEqual(TextCase.capitalize.apply(to: ""), "")
    }

    // Font.resolvedLineSpacing

    func testResolvedLineSpacingDefault() {
        let font = Font()
        // (1.2 - 1.0) * 17 = 3.4
        XCTAssertEqual(font.resolvedLineSpacing, 0.2 * 17, accuracy: 0.001)
    }

    func testResolvedLineSpacingHeightOne() {
        let font = Font(height: 1.0)
        XCTAssertEqual(font.resolvedLineSpacing, 0)
    }

    func testResolvedLineSpacingBelowOne() {
        let font = Font(height: 0.8)
        // max(0, (0.8 - 1.0) * 17) = max(0, -3.4) = 0
        XCTAssertEqual(font.resolvedLineSpacing, 0)
    }

    func testResolvedLineSpacingLarge() {
        let font = Font(size: 20, height: 2.0)
        // (2.0 - 1.0) * 20 = 20
        XCTAssertEqual(font.resolvedLineSpacing, 20, accuracy: 0.001)
    }

    // TextStyle defaults

    func testTextStyleDefaults() {
        let style = TextStyle()
        XCTAssertNil(style.color)
        XCTAssertNil(style.maxLines)
        XCTAssertEqual(style.align, .leading)
        XCTAssertEqual(style.textCase, .plain)
        XCTAssertEqual(style.overflow, .ellipsis)
        XCTAssertNil(style.decoration)
    }

    // Font defaults

    func testFontDefaults() {
        let font = Font()
        XCTAssertNil(font.family)
        XCTAssertEqual(font.size, 17)
        XCTAssertEqual(font.height, 1.2)
        XCTAssertEqual(font.tracking, 0)
        XCTAssertEqual(font.weight, 400)
        XCTAssertFalse(font.italic)
        XCTAssertNil(font.features)
    }

    // FontFeatures defaults

    func testFontFeaturesDefaults() {
        let features = FontFeatures()
        XCTAssertTrue(features.stylisticSets.isEmpty)
        XCTAssertTrue(features.alternates.isEmpty)
        XCTAssertTrue(features.axes.isEmpty)
        XCTAssertTrue(features.rawTags.isEmpty)
    }

    // FontAxis raw values

    func testFontAxisRawValues() {
        XCTAssertEqual(FontAxis.weight.code, "wght")
        XCTAssertEqual(FontAxis.width.code, "wdth")
        XCTAssertEqual(FontAxis.slant.code, "slnt")
        XCTAssertEqual(FontAxis.italic.code, "ital")
        XCTAssertEqual(FontAxis.opticalSize.code, "opsz")
        XCTAssertEqual(FontAxis.fill.code, "FILL")
        XCTAssertEqual(FontAxis.grade.code, "GRAD")
        XCTAssertEqual(FontAxis.monospace.code, "MONO")
        XCTAssertEqual(FontAxis.casualness.code, "CASL")
        XCTAssertEqual(FontAxis.cursive.code, "CRSV")
        XCTAssertEqual(FontAxis.softness.code, "SOFT")
        XCTAssertEqual(FontAxis.roundness.code, "ROND")
    }

    // TextAlign mapping

    func testTextAlignNSTextAlignment() {
        XCTAssertEqual(TextAlign.leading.nsTextAlignment, .natural)
        XCTAssertEqual(TextAlign.trailing.nsTextAlignment, .right)
        XCTAssertEqual(TextAlign.center.nsTextAlignment, .center)
        XCTAssertEqual(TextAlign.justify.nsTextAlignment, .justified)
    }

    // TextOverflow mapping

    func testTextOverflowLineBreakMode() {
        XCTAssertEqual(TextOverflow.clip.lineBreakMode, .byClipping)
        XCTAssertEqual(TextOverflow.fade.lineBreakMode, .byClipping)
        XCTAssertEqual(TextOverflow.ellipsis.lineBreakMode, .byTruncatingTail)
    }

    // MARK: - 2. Mount — UILabel property assignment

    func testMountProducesUILabel() {
        let text = Text("Hello")
        let view = text.makeRenderer().mount()
        XCTAssertTrue(view is UILabel)
    }

    func testMountSetsTextContent() {
        let label = mount(Text("Hello"))
        XCTAssertEqual(label.attributedText?.string, "Hello")
    }

    func testMountAppliesTextCase() {
        let style = TextStyle(textCase: .uppercase)
        let label = mount(Text("hello", style: style))
        XCTAssertEqual(label.attributedText?.string, "HELLO")
    }

    func testMountSetsFontSize() {
        let style = TextStyle(font: Font(size: 24))
        let label = mount(Text("Hi", style: style))
        let font = attributes(of: label)[.font] as? UIFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 24)
    }

    func testMountDefaultColor() {
        let label = mount(Text("Hi"))
        let color = attributes(of: label)[.foregroundColor] as? UIColor
        XCTAssertEqual(color, .label)
    }

    func testMountCustomColor() {
        let style = TextStyle(color: .red)
        let label = mount(Text("Hi", style: style))
        let color = attributes(of: label)[.foregroundColor] as? UIColor
        XCTAssertEqual(color, .red)
    }

    func testMountAlignmentLeading() {
        let label = mount(Text("Hi", style: TextStyle(align: .leading)))
        XCTAssertEqual(paragraphStyle(of: label)?.alignment, .natural)
    }

    func testMountAlignmentCenter() {
        let label = mount(Text("Hi", style: TextStyle(align: .center)))
        XCTAssertEqual(paragraphStyle(of: label)?.alignment, .center)
    }

    func testMountAlignmentTrailing() {
        let label = mount(Text("Hi", style: TextStyle(align: .trailing)))
        XCTAssertEqual(paragraphStyle(of: label)?.alignment, .right)
    }

    func testMountAlignmentJustify() {
        let label = mount(Text("Hi", style: TextStyle(align: .justify)))
        XCTAssertEqual(paragraphStyle(of: label)?.alignment, .justified)
    }

    func testMountOverflowEllipsis() {
        let label = mount(Text("Hi", style: TextStyle(overflow: .ellipsis)))
        XCTAssertEqual(paragraphStyle(of: label)?.lineBreakMode, .byTruncatingTail)
    }

    func testMountOverflowClip() {
        let label = mount(Text("Hi", style: TextStyle(overflow: .clip)))
        XCTAssertEqual(paragraphStyle(of: label)?.lineBreakMode, .byClipping)
    }

    func testMountLineSpacing() throws {
        let font = Font(size: 20, height: 1.5)
        let label = mount(Text("Hi", style: TextStyle(font: font)))
        // (1.5 - 1.0) * 20 = 10
        let lineSpacing = try XCTUnwrap(paragraphStyle(of: label)?.lineSpacing)
        XCTAssertEqual(lineSpacing, 10, accuracy: 0.001)
    }

    func testMountTracking() {
        let font = Font(tracking: 2.5)
        let label = mount(Text("Hi", style: TextStyle(font: font)))
        let kern = attributes(of: label)[.kern] as? CGFloat
        XCTAssertEqual(kern, 2.5)
    }

    func testMountDefaultMaxLinesIsUnlimited() {
        let label = mount(Text("Hi"))
        XCTAssertEqual(label.numberOfLines, 0)
    }

    func testMountMaxLines() {
        let style = TextStyle(maxLines: 3)
        let label = mount(Text("Hi", style: style))
        XCTAssertEqual(label.numberOfLines, 3)
    }

    func testMountUnderline() {
        let decoration = TextDecoration(underline: TextLineStyle(style: TextLineStyle.single))
        let style = TextStyle(decoration: decoration)
        let label = mount(Text("Hi", style: style))
        let attrs = attributes(of: label)
        XCTAssertEqual(attrs[.underlineStyle] as? Int, TextLineStyle.single)
        XCTAssertNil(attrs[.strikethroughStyle])
    }

    func testMountUnderlineWithColor() {
        let decoration = TextDecoration(underline: TextLineStyle(color: .blue))
        let style = TextStyle(decoration: decoration)
        let label = mount(Text("Hi", style: style))
        let attrs = attributes(of: label)
        XCTAssertEqual(attrs[.underlineColor] as? UIColor, .blue)
    }

    func testMountStrikethrough() {
        let decoration = TextDecoration(strikethrough: TextLineStyle(style: TextLineStyle.double))
        let style = TextStyle(decoration: decoration)
        let label = mount(Text("Hi", style: style))
        let attrs = attributes(of: label)
        XCTAssertEqual(attrs[.strikethroughStyle] as? Int, TextLineStyle.double)
        XCTAssertNil(attrs[.underlineStyle])
    }

    func testMountShadow() {
        let shadow = ShadowConfig(color: .red, radius: 5, offset: CGSize(width: 2, height: 3))
        let decoration = TextDecoration(shadow: shadow)
        let style = TextStyle(decoration: decoration)
        let label = mount(Text("Hi", style: style))
        let nsShadow = attributes(of: label)[.shadow] as? NSShadow
        XCTAssertNotNil(nsShadow)
        XCTAssertEqual(nsShadow?.shadowBlurRadius, 5)
        XCTAssertEqual(nsShadow?.shadowOffset, CGSize(width: 2, height: 3))
    }

    func testMountNoDecorationAttributes() {
        let label = mount(Text("Hi"))
        let attrs = attributes(of: label)
        XCTAssertNil(attrs[.underlineStyle])
        XCTAssertNil(attrs[.strikethroughStyle])
        XCTAssertNil(attrs[.shadow])
    }

    // MARK: - 3. Update

    func testUpdateChangesText() {
        let renderer = UIKitTextRenderer(view: Text("Hello", style: TextStyle()))
        let label = renderer.mount() as! UILabel
        XCTAssertEqual(label.attributedText?.string, "Hello")

        renderer.update(from: Text("World", style: TextStyle()))
        XCTAssertEqual(label.attributedText?.string, "World")
    }

    func testUpdateChangesColor() {
        let renderer = UIKitTextRenderer(view: Text("Hi", style: TextStyle(color: .red)))
        let label = renderer.mount() as! UILabel

        renderer.update(from: Text("Hi", style: TextStyle(color: .blue)))
        let color = attributes(of: label)[.foregroundColor] as? UIColor
        XCTAssertEqual(color, Color.blue.platformColor)
    }

    func testUpdateChangesMaxLines() {
        let renderer = UIKitTextRenderer(view: Text("Hi", style: TextStyle(maxLines: 1)))
        let label = renderer.mount() as! UILabel
        XCTAssertEqual(label.numberOfLines, 1)

        renderer.update(from: Text("Hi", style: TextStyle(maxLines: 5)))
        XCTAssertEqual(label.numberOfLines, 5)
    }

    func testUpdateChangesAlignment() {
        let renderer = UIKitTextRenderer(view: Text("Hi", style: TextStyle(align: .leading)))
        let label = renderer.mount() as! UILabel

        renderer.update(from: Text("Hi", style: TextStyle(align: .center)))
        XCTAssertEqual(paragraphStyle(of: label)?.alignment, .center)
    }

    func testUpdateAddsDecoration() {
        let renderer = UIKitTextRenderer(view: Text("Hi", style: TextStyle()))
        let label = renderer.mount() as! UILabel
        XCTAssertNil(attributes(of: label)[.underlineStyle])

        let decoration = TextDecoration(underline: TextLineStyle())
        renderer.update(from: Text("Hi", style: TextStyle(decoration: decoration)))
        XCTAssertNotNil(attributes(of: label)[.underlineStyle])
    }

    func testUpdateRemovesDecoration() {
        let decoration = TextDecoration(underline: TextLineStyle())
        let renderer = UIKitTextRenderer(view: Text("Hi", style: TextStyle(decoration: decoration)))
        let label = renderer.mount() as! UILabel
        XCTAssertNotNil(attributes(of: label)[.underlineStyle])

        renderer.update(from: Text("Hi", style: TextStyle()))
        XCTAssertNil(attributes(of: label)[.underlineStyle])
    }

    // MARK: - 4. Sizing under constraints

    func testSingleLineSizeFitsContent() {
        let label = mount(Text("Hello", style: TextStyle(maxLines: 1)))
        let size = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }

    func testMultiLineWrapsWithinWidth() {
        let longText = String(repeating: "Hello world ", count: 50)
        let label = mount(Text(longText))
        let singleLineSize = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        let constrainedSize = label.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        // Constrained width should produce greater height due to wrapping
        XCTAssertGreaterThan(constrainedSize.height, singleLineSize.height)
    }

    func testMaxLinesOneCapsHeight() {
        let longText = String(repeating: "Hello world ", count: 50)
        let singleLine = mount(Text(longText, style: TextStyle(maxLines: 1)))
        let unlimited = mount(Text(longText))

        let singleSize = singleLine.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        let unlimitedSize = unlimited.sizeThatFits(CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        // Single line should be shorter than unlimited wrapping
        XCTAssertLessThan(singleSize.height, unlimitedSize.height)
    }

    func testEmptyStringSize() {
        let label = mount(Text(""))
        let size = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        // UILabel with empty attributed string reports zero size
        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 0)
    }
}

#endif
