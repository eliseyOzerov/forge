#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class TextThemeTests: XCTestCase {

    // MARK: - Token defaults

    func testSharedSizeRampDefaults() {
        XCTAssertEqual(TextSize.xxs.defaultValue, 10)
        XCTAssertEqual(TextSize.rg.defaultValue, 16)
        XCTAssertEqual(TextSize.xl.defaultValue, 24)
        XCTAssertEqual(TextSize.xl5.defaultValue, 96)
    }

    func testWeightRampMatchesCssValues() {
        XCTAssertEqual(TextWeight.regular.defaultValue, 400)
        XCTAssertEqual(TextWeight.bold.defaultValue, 700)
        XCTAssertEqual(TextWeight.black.defaultValue, 900)
    }

    func testTokenEqualityIsByName() {
        XCTAssertEqual(TextSize("xs", 12), TextSize("xs", 999))
        XCTAssertEqual(TextRole("custom"), TextRole("custom"))
    }

    // MARK: - RoleTheme subscript fallback

    func testRoleFallsBackToPrimaryScaledToSize() {
        let role = RoleTheme(primary: Font(size: 100))  // primary size irrelevant
        let resolved = role[.xl2]
        XCTAssertEqual(resolved.size, CGFloat(TextSize.xl2.defaultValue))
    }

    func testRoleExplicitSizeWins() {
        var sizes: [TextSize: Font] = [:]
        sizes[.rg] = Font(size: 17, weight: 700)
        let role = RoleTheme(primary: Font(), sizes: sizes)
        XCTAssertEqual(role.rg.size, 17)
        XCTAssertEqual(role.rg.weight, 700)
    }

    // MARK: - Standard TextTheme

    func testStandardHasAllFiveRoles() {
        let theme = TextTheme.standard()
        XCTAssertEqual(theme.roles.count, 5)
        XCTAssertNotNil(theme.roles[.display])
        XCTAssertNotNil(theme.roles[.value])
        XCTAssertNotNil(theme.roles[.title])
        XCTAssertNotNil(theme.roles[.body])
        XCTAssertNotNil(theme.roles[.label])
    }

    func testStandardRolesUseConventionalWeights() {
        let theme = TextTheme.standard()
        XCTAssertEqual(theme.display.primary.weight, 700)   // bold
        XCTAssertEqual(theme.body.primary.weight, 400)      // regular
        XCTAssertEqual(theme.label.primary.weight, 500)     // medium
    }

    // MARK: - Extensibility

    func testCustomRoleResolvesViaSubscript() {
        let marketing = TextRole("marketing")
        var theme = TextTheme.standard()
        theme = theme.copy {
            $0.roles[marketing] = RoleTheme(primary: Font(size: 20, weight: 900))
        }
        XCTAssertEqual(theme[marketing].primary.weight, 900)
    }

    func testUnknownRoleFallsBackToThemePrimary() {
        let theme = TextTheme(primary: Font(size: 14))
        let unknown = TextRole("mystery")
        // Falls back to a RoleTheme built from `primary` — size comes
        // from the requested TextSize default, not primary.size.
        XCTAssertEqual(theme[unknown].rg.size, CGFloat(TextSize.rg.defaultValue))
    }

    // MARK: - Copy

    func testCopyOnSingleRoleDoesNotAffectOthers() {
        let base = TextTheme.standard()
        let custom = base.copy {
            $0.roles[.body] = RoleTheme(primary: Font(size: 14, weight: 300))
        }
        XCTAssertEqual(custom.body.primary.weight, 300)
        XCTAssertEqual(custom.display.primary.weight,
                       base.display.primary.weight,
                       "Display role untouched")
    }
}
#endif
