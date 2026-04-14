#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class ThemeSlotTests: XCTestCase {

    func testCtxThemeReturnsProvidedTokens() throws {
        let tokens = TokenTheme.light()
        var observedXs: Double?
        var observedLabel: Color?

        let tree = Provided(tokens) {
            Buildable { ctx in
                observedXs = ctx.theme(.tokens).spacing.xs
                observedLabel = ctx.theme(.tokens).color.label.primary
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)

        XCTAssertEqual(try XCTUnwrap(observedXs), 8)
        XCTAssertNotNil(observedLabel)
    }

    func testIndividualThemesAccessibleViaTheirOwnSlots() throws {
        let spacing = SpacingTheme.standard()
        let color = ColorTheme.light()

        var spacingVal: Double?
        var colorVal: Color?

        let tree = Provided(spacing, color) {
            Buildable { ctx in
                spacingVal = ctx.theme(.spacing).lg
                colorVal = ctx.theme(.color).label.primary
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)

        XCTAssertEqual(try XCTUnwrap(spacingVal), 24)
        XCTAssertNotNil(colorVal)
    }
}
#endif
