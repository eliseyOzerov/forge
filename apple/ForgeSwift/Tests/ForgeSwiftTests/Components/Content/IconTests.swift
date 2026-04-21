import Testing
@testable import ForgeSwift

// MARK: - IconStyle & IconTheme (platform-agnostic)

@Suite("IconStyle")
struct IconStyleTests {

    @Test func defaults() {
        let style = IconStyle()
        #expect(style.size == 24)
        #expect(style.color == nil)
        #expect(style.weight == nil)
        #expect(style.thickness == nil)
    }

    @Test func initWithFields() {
        let style = IconStyle(size: 32, color: .red, weight: .bold, thickness: 2.0)
        #expect(style.size == 32)
        #expect(style.color == .red)
        #expect(style.weight == .bold)
        #expect(style.thickness == 2.0)
    }
}

@Suite("IconRole")
struct IconRoleTests {

    @Test func equality() {
        #expect(IconRole.primary == IconRole("primary"))
        #expect(IconRole.primary != IconRole.secondary)
    }

    @Test func defaultChain() {
        #expect(IconRole.defaultChain.count == 4)
        #expect(IconRole.defaultChain.first == .primary)
    }
}

@Suite("IconTheme")
struct IconThemeTests {

    @Test func cascade() {
        let theme = IconTheme(primary: IconStyle(size: 20))
        #expect(theme.primary.size == 20)
        #expect(theme.secondary.size == 20)
    }

    @Test func perRole() {
        let theme = IconTheme(
            primary: IconStyle(size: 20),
            secondary: IconStyle(size: 16)
        )
        #expect(theme.primary.size == 20)
        #expect(theme.secondary.size == 16)
        #expect(theme.tertiary.size == 16)
    }

    @Test func standard() {
        let theme = IconTheme.standard()
        #expect(theme.primary.size == 24)
    }
}

// MARK: - WeightScale

@Suite("WeightScale")
struct WeightScaleTests {

    @Test func numericResolution() {
        let scale = WeightScale.standard()
        #expect(scale.numericValue(for: .regular) == 400)
        #expect(scale.numericValue(for: .bold) == 700)
        #expect(scale.numericValue(for: .numeric(550)) == 550)
    }

    @Test func customNumericOverride() {
        var scale = WeightScale.standard()
        scale.values[.medium] = 545
        #expect(scale.numericValue(for: .medium) == 545)
    }

    @Test func thicknessInterpolation() {
        let scale = WeightScale(thicknessMap: [100: 0.5, 900: 3.5])
        #expect(scale.thickness(for: .ultraLight) == 0.5)
        #expect(scale.thickness(for: .black) == 3.5)
        #expect(scale.thickness(for: .numeric(500)) == 2.0)
    }

    @Test func thicknessClamp() {
        let scale = WeightScale(thicknessMap: [200: 1.0, 800: 3.0])
        #expect(scale.thickness(for: .numeric(50)) == 1.0)
        #expect(scale.thickness(for: .numeric(950)) == 3.0)
    }

    @Test func standardDefaults() {
        let scale = WeightScale.standard()
        #expect(scale.thickness(for: .ultraLight) == 0.5)
        #expect(scale.thickness(for: .regular) == 1.5)
        #expect(scale.thickness(for: .bold) == 2.5)
        #expect(scale.thickness(for: .black) == 3.5)
    }
}

// MARK: - WeightToken

@Suite("WeightToken")
struct WeightTokenTests {

    @Test func defaults() {
        #expect(WeightToken.regular.defaultValue == 400)
        #expect(WeightToken.bold.defaultValue == 700)
        #expect(WeightToken.black.defaultValue == 900)
    }

    @Test func mapOverride() {
        var map = TokenMap<WeightToken>()
        map[.medium] = 545
        #expect(map[.medium] == 545)
        #expect(map[.regular] == 400)
    }
}

// MARK: - Icon view (UIKit only)

#if canImport(UIKit)
import XCTest
import UIKit

@MainActor
final class IconViewTests: XCTestCase {

    func testDefaultInit() {
        let icon = Icon("arrow.right")
        XCTAssertEqual(icon.source, .asset("arrow.right"))
        XCTAssertEqual(icon.style.size, 24)
        XCTAssertNil(icon.style.color)
        XCTAssertNil(icon.style.weight)
        XCTAssertNil(icon.style.thickness)
    }

    func testSvgInit() {
        let icon = Icon(svg: "<svg></svg>")
        XCTAssertEqual(icon.source, .svg("<svg></svg>"))
    }

    func testStyleModifier() {
        let icon = Icon("check")
            .style { $0.copy { $0.size = 32; $0.color = .red } }
        XCTAssertEqual(icon.style.size, 32)
        XCTAssertEqual(icon.style.color, .red)
    }

    func testMountProducesView() {
        let icon = Icon(svg: "<svg viewBox=\"0 0 24 24\"><path d=\"M0 0h24v24H0z\"/></svg>")
        let renderer = icon.makeRenderer()
        let view = renderer.mount()
        XCTAssertTrue(view is IconCanvasView)
    }

    func testIntrinsicContentSize() {
        let icon = Icon(svg: "<svg viewBox=\"0 0 24 24\"></svg>")
            .style { $0.copy { $0.size = 32 } }
        let renderer = icon.makeRenderer()
        let view = renderer.mount() as! IconCanvasView
        XCTAssertEqual(view.intrinsicContentSize, CGSize(width: 32, height: 32))
    }
}

#endif
