#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class IconTests: XCTestCase {

    // MARK: - Mount

    func testMountProducesImageView() {
        let icon = Icon("checkmark")
        let renderer = icon.makeRenderer()
        let view = renderer.mount()
        XCTAssertTrue(view is UIImageView)
    }

    func testMountWithValidName() {
        let icon = Icon("checkmark")
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    func testMountWithInvalidName() {
        let icon = Icon("nonexistent_symbol_xyz")
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertNil(view.image)
    }

    // MARK: - Style Defaults

    func testDefaultStyle() {
        let style = IconStyle()
        XCTAssertEqual(style.size, 24)
        XCTAssertEqual(style.weight, .regular)
        XCTAssertNil(style.color)
        XCTAssertEqual(style.renderingMode, .template)
    }

    // MARK: - Template Rendering

    func testTemplateSetsAlwaysTemplate() {
        let icon = Icon("star.fill", style: IconStyle(renderingMode: .template))
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.image?.renderingMode, .alwaysTemplate)
    }

    func testTemplateSetsTintColor() {
        let icon = Icon("star.fill", style: IconStyle(color: .red))
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.tintColor, Color.red.platformColor)
    }

    func testTemplateDefaultTintIsLabel() {
        let icon = Icon("star.fill", style: IconStyle())
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.tintColor, .label)
    }

    // MARK: - Original Rendering

    func testOriginalSetsAlwaysOriginal() {
        let icon = Icon("star.fill", style: IconStyle(renderingMode: .original))
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.image?.renderingMode, .alwaysOriginal)
    }

    // MARK: - Weight

    func testAllWeights() {
        let weights: [IconWeight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for weight in weights {
            let icon = Icon("circle", style: IconStyle(weight: weight))
            let view = icon.makeRenderer().mount() as! UIImageView
            XCTAssertNotNil(view.image, "Failed for weight: \(weight)")
        }
    }

    // MARK: - Update

    func testUpdateChangesImage() {
        let renderer1 = UIKitIconRenderer(name: "star", style: IconStyle())
        let view = renderer1.mount()

        let renderer2 = UIKitIconRenderer(name: "heart", style: IconStyle())
        renderer2.update(view)

        let imageView = view as! UIImageView
        XCTAssertNotNil(imageView.image)
    }

    func testUpdateChangesColor() {
        let renderer1 = UIKitIconRenderer(name: "star", style: IconStyle(color: .red))
        let view = renderer1.mount()

        let renderer2 = UIKitIconRenderer(name: "star", style: IconStyle(color: .blue))
        renderer2.update(view)

        let imageView = view as! UIImageView
        XCTAssertEqual(imageView.tintColor, Color.blue.platformColor)
    }

    // MARK: - Content Hugging

    func testContentHuggingRequired() {
        let icon = Icon("star")
        let view = icon.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentHuggingPriority(for: .horizontal), .required)
        XCTAssertEqual(view.contentHuggingPriority(for: .vertical), .required)
    }

    // MARK: - IconRenderingMode

    func testIsTemplate() {
        XCTAssertTrue(IconRenderingMode.template.isTemplate)
        XCTAssertFalse(IconRenderingMode.original.isTemplate)
        XCTAssertFalse(IconRenderingMode.hierarchical.isTemplate)
        XCTAssertFalse(IconRenderingMode.palette.isTemplate)
    }
}

#endif
