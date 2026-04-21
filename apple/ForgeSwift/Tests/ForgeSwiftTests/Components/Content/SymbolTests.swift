#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class SymbolTests: XCTestCase {

    // MARK: - Mount

    func testMountProducesImageView() {
        let symbol = Symbol("checkmark")
        let renderer = symbol.makeRenderer()
        let view = renderer.mount()
        XCTAssertTrue(view is UIImageView)
    }

    func testMountWithValidName() {
        let symbol = Symbol("checkmark")
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    func testMountWithInvalidName() {
        let symbol = Symbol("nonexistent_symbol_xyz")
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNil(view.image)
    }

    // MARK: - Style Defaults

    func testDefaultStyle() {
        let style = SymbolStyle()
        XCTAssertEqual(style.size, 24)
        XCTAssertNil(style.weight)
        XCTAssertNil(style.color)
        XCTAssertEqual(style.scale, .medium)
        XCTAssertEqual(style.mode, .monochrome)
        XCTAssertNil(style.value)
    }

    // MARK: - Monochrome Rendering

    func testMonochromeSetsAlwaysTemplate() {
        let symbol = Symbol("star.fill", style: SymbolStyle(mode: .monochrome))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.image?.renderingMode, .alwaysTemplate)
    }

    func testMonochromeSetsTintColor() {
        let symbol = Symbol("star.fill", style: SymbolStyle(color: .red))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.tintColor, Color.red.platformColor)
    }

    func testMonochromeDefaultTintIsLabel() {
        let symbol = Symbol("star.fill", style: SymbolStyle())
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.tintColor, .label)
    }

    // MARK: - Multicolor Rendering

    func testMulticolorSetsAlwaysOriginal() {
        let symbol = Symbol("star.fill", style: SymbolStyle(mode: .multicolor))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.image?.renderingMode, .alwaysOriginal)
    }

    // MARK: - Weight

    func testSemanticWeights() {
        let weights: [Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for weight in weights {
            let symbol = Symbol("circle", style: SymbolStyle(weight: weight))
            let view = symbol.makeRenderer().mount() as! UIImageView
            XCTAssertNotNil(view.image, "Failed for weight: \(weight)")
        }
    }

    func testNumericWeight() {
        let symbol = Symbol("circle", style: SymbolStyle(weight: .numeric(500)))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    // MARK: - Scale

    func testAllScales() {
        let scales: [SymbolScale] = [.small, .medium, .large]
        for scale in scales {
            let symbol = Symbol("circle", style: SymbolStyle(scale: scale))
            let view = symbol.makeRenderer().mount() as! UIImageView
            XCTAssertNotNil(view.image, "Failed for scale: \(scale)")
        }
    }

    // MARK: - Variable Value

    func testVariableValue() {
        let symbol = Symbol("speaker.wave.3", style: SymbolStyle(value: 0.5))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    // MARK: - Mode

    func testPaletteMode() {
        let symbol = Symbol("star.fill", style: SymbolStyle(mode: .palette(.red, .blue, nil)))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    func testHierarchicalMode() {
        let symbol = Symbol("star.fill", style: SymbolStyle(mode: .hierarchical))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    // MARK: - Update

    func testUpdateChangesImage() {
        let renderer = UIKitSymbolRenderer(view: Symbol("star", style: SymbolStyle()))
        let view = renderer.mount()

        renderer.update(from: Symbol("heart", style: SymbolStyle()))

        let imageView = view as! UIImageView
        XCTAssertNotNil(imageView.image)
    }

    func testUpdateChangesColor() {
        let renderer = UIKitSymbolRenderer(view: Symbol("star", style: SymbolStyle(color: .red)))
        let view = renderer.mount()

        renderer.update(from: Symbol("star", style: SymbolStyle(color: .blue)))

        let imageView = view as! UIImageView
        XCTAssertEqual(imageView.tintColor, Color.blue.platformColor)
    }

    // MARK: - Content Hugging

    func testContentHuggingRequired() {
        let symbol = Symbol("star")
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentHuggingPriority(for: .horizontal), .required)
        XCTAssertEqual(view.contentHuggingPriority(for: .vertical), .required)
    }

    // MARK: - Custom Size

    func testCustomSize() {
        let symbol = Symbol("star.fill", style: SymbolStyle(size: 48))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        let defaultSymbol = Symbol("star.fill", style: SymbolStyle(size: 24))
        let defaultView = defaultSymbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotEqual(view.image?.size, defaultView.image?.size)
    }

    func testEmptyStringName() {
        let symbol = Symbol("")
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNil(view.image)
    }

    func testCombinedStyleColorAndSize() {
        let symbol = Symbol("star.fill", style: SymbolStyle(size: 32, color: .blue))
        let view = symbol.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.tintColor, Color.blue.platformColor)
    }

    // MARK: - Theme

    func testSymbolThemeStandard() {
        let theme = SymbolTheme.standard()
        let style = theme.primary
        XCTAssertEqual(style.size, 24)
    }

    func testSymbolRoleConstants() {
        XCTAssertEqual(SymbolRole.primary.name, "primary")
        XCTAssertEqual(SymbolRole.secondary.name, "secondary")
        XCTAssertEqual(SymbolRole.defaultChain.count, 4)
    }
}

#endif
