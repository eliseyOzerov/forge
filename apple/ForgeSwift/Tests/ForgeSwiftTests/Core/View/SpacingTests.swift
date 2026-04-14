import XCTest
@testable import ForgeSwift

@MainActor
final class SpacingThemeTests: XCTestCase {

    // MARK: - SpacingToken defaults

    func testBuiltInTokensHaveExpectedDefaults() {
        XCTAssertEqual(SpacingToken.xxs.defaultValue, 4)
        XCTAssertEqual(SpacingToken.xs.defaultValue, 8)
        XCTAssertEqual(SpacingToken.sm.defaultValue, 12)
        XCTAssertEqual(SpacingToken.rg.defaultValue, 16)
        XCTAssertEqual(SpacingToken.md.defaultValue, 20)
        XCTAssertEqual(SpacingToken.lg.defaultValue, 24)
        XCTAssertEqual(SpacingToken.xl.defaultValue, 32)
        XCTAssertEqual(SpacingToken.xl2.defaultValue, 48)
        XCTAssertEqual(SpacingToken.xl3.defaultValue, 64)
        XCTAssertEqual(SpacingToken.xl4.defaultValue, 96)
        XCTAssertEqual(SpacingToken.xl5.defaultValue, 128)
    }

    func testTokenEqualityIsByName() {
        let a = SpacingToken("custom", 10)
        let b = SpacingToken("custom", 999)
        XCTAssertEqual(a, b, "Equality should key off name, not default")
    }

    // MARK: - Subscript + fallback

    func testEmptyThemeFallsBackToTokenDefault() {
        let theme = SpacingTheme()
        XCTAssertEqual(theme[.xs], 8)
        XCTAssertEqual(theme[.xl5], 128)
    }

    func testStandardThemePopulatesAllBuiltIns() {
        let theme = SpacingTheme.standard()
        XCTAssertEqual(theme.values.count, 11)
        XCTAssertEqual(theme.xs, 8)
        XCTAssertEqual(theme.xl5, 128)
    }

    // MARK: - Extensibility

    func testCustomTokenResolvesFromIntrinsicDefault() {
        let huge = SpacingToken("huge", 200)
        let theme = SpacingTheme.standard()
        XCTAssertEqual(theme[huge], 200, "Custom tokens fall back to their intrinsic default")
    }

    func testCustomTokenCanBeOverriddenInTheme() {
        let huge = SpacingToken("huge", 200)
        let theme = SpacingTheme.standard().copy { $0.values[huge] = 300 }
        XCTAssertEqual(theme[huge], 300)
    }

    // MARK: - Copy semantics

    func testCopyOverridesSingleToken() {
        let base = SpacingTheme.standard()
        let tight = base.copy { $0.values[.xs] = 6 }
        XCTAssertEqual(tight.xs, 6)
        XCTAssertEqual(tight.sm, 12, "Non-overridden tokens are unchanged")
        XCTAssertEqual(base.xs, 8, "Original theme is not mutated")
    }

    func testWhiteLabelBrandPatternWorks() {
        // Simulates a white-label app providing brand-specific overrides
        // for both built-in and custom tokens.
        let humongous = SpacingToken("humongous", 200)
        let brandA = SpacingTheme.standard().copy {
            $0.values[.xs] = 10
            $0.values[humongous] = 180
        }
        let brandB = SpacingTheme.standard().copy {
            $0.values[humongous] = 240
        }
        XCTAssertEqual(brandA.xs, 10)
        XCTAssertEqual(brandA[humongous], 180)
        XCTAssertEqual(brandB.xs, 8, "Brand B didn't override xs")
        XCTAssertEqual(brandB[humongous], 240)
    }
}
