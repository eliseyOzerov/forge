#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

@MainActor
final class ColorThemeTests: XCTestCase {

    // MARK: - Color.inverse / luminance / withInverse

    func testInverseFallsBackToBlackOnBrightColor() {
        let bright = Color(1, 1, 0.9)  // near-white
        XCTAssertEqual(bright.inverse, .black)
    }

    func testInverseFallsBackToWhiteOnDarkColor() {
        let dark = Color(0.05, 0.05, 0.1)
        XCTAssertEqual(dark.inverse, .white)
    }

    func testInverseUsesOverrideWhenSet() {
        let colored = Color(0, 1, 0).withInverse(.red)
        XCTAssertEqual(colored.inverse, .red)
    }

    func testWithInversePreservesRGBA() {
        let base = Color(0.2, 0.4, 0.6, 0.8)
        let withInv = base.withInverse(.white)
        XCTAssertEqual(withInv.red, 0.2)
        XCTAssertEqual(withInv.green, 0.4)
        XCTAssertEqual(withInv.blue, 0.6)
        XCTAssertEqual(withInv.alpha, 0.8)
    }

    func testWithAlphaPreservesInverseOverride() {
        let base = Color.red.withInverse(.white)
        let faded = base.withAlpha(0.5)
        XCTAssertEqual(faded.alpha, 0.5)
        XCTAssertEqual(faded.inverse, .white)
    }

    func testLuminanceMonotonic() {
        // Brighter colors should have higher luminance.
        XCTAssertLessThan(Color.black.luminance, Color.gray.luminance)
        XCTAssertLessThan(Color.gray.luminance, Color.white.luminance)
    }

    // MARK: - Copyable

    func testCopyMutatesOnlyRequestedFields() {
        let theme = ColorTheme.light()
        let copy = theme.copy {
            $0.surface.primary = .red
        }
        XCTAssertEqual(copy.surface.primary, .red)
        XCTAssertEqual(copy.label.primary, theme.label.primary)  // untouched
    }

    // MARK: - PriorityTokens

    func testPriorityFallsBackToPrimary() {
        let tokens = PriorityTokens(primary: .red)
        XCTAssertEqual(tokens.primary, .red)
        XCTAssertEqual(tokens.secondary, .red)
        XCTAssertEqual(tokens.tertiary, .red)
        XCTAssertEqual(tokens.quaternary, .red)
    }

    func testPriorityCascadesThroughDefinedLevels() {
        let tokens = PriorityTokens(primary: .red, secondary: .green)
        XCTAssertEqual(tokens.secondary, .green)
        XCTAssertEqual(tokens.tertiary, .green)    // falls back to secondary
        XCTAssertEqual(tokens.quaternary, .green)  // falls back to secondary
    }

    func testPriorityRespectsAllFourLevels() {
        let tokens = PriorityTokens(
            primary: .red,
            secondary: .green,
            tertiary: .blue,
            quaternary: .yellow
        )
        XCTAssertEqual(tokens.primary, .red)
        XCTAssertEqual(tokens.secondary, .green)
        XCTAssertEqual(tokens.tertiary, .blue)
        XCTAssertEqual(tokens.quaternary, .yellow)
    }

    // MARK: - HueScale / ColorPalette / HueToken

    func testPaletteGeneratesAll12Hues() {
        let palette = ColorPalette.generate()
        for hue in Hue.allCases {
            let token = palette[hue]
            XCTAssertEqual(token.canonical, hue)
        }
    }

    func testHueScaleStepMonotonicInLightness() {
        let palette = ColorPalette.generate()
        let scale = palette.blue.primary
        // s0 brightest, s10 darkest — luminance should decrease
        XCTAssertGreaterThan(scale.s0.luminance, scale.s5.luminance)
        XCTAssertGreaterThan(scale.s5.luminance, scale.s10.luminance)
    }

    func testStandardIsPrimaryMiddleStep() {
        let palette = ColorPalette.generate()
        XCTAssertEqual(palette.red.standard, palette.red.primary.s5)
    }

    func testSubscriptOutOfRangeReturnsMiddle() {
        let scale = ColorPalette.generate().red.primary
        XCTAssertEqual(scale[-1], scale.s5)
        XCTAssertEqual(scale[100], scale.s5)
    }

    func testRotateDropsCanonicalAndSystem() {
        let palette = ColorPalette.generate()
        let rotated = palette.red.rotate(19)
        XCTAssertNil(rotated.canonical)
        XCTAssertNil(rotated.system)
        // Angle shifted
        XCTAssertEqual(rotated.angle, palette.red.angle + 19, accuracy: 0.001)
    }

    func testSystemColorAvailableForKnownHues() {
        let palette = ColorPalette.generate()
        // These have UIColor counterparts on iOS.
        XCTAssertNotNil(palette.red.system)
        XCTAssertNotNil(palette.blue.system)
        XCTAssertNotNil(palette.green.system)
        // These don't.
        XCTAssertNil(palette.lime.system)
        XCTAssertNil(palette.magenta.system)
    }

    func testCustomColorsDeriveFromPalette() {
        let palette = ColorPalette.generate()
        XCTAssertEqual(palette.custom.moss, palette.green.muted.s7)
        XCTAssertEqual(palette.custom.lavender, palette.purple.muted.s3)
    }

    func testHueAnglesCustomizable() {
        var angles: [Hue: Double] = .defaultHueAngles
        angles[.red] = 10  // shift red toward pink
        let palette = ColorPalette.generate(hueAngles: angles)
        XCTAssertEqual(palette.red.angle, 10, accuracy: 0.001)
    }

    // MARK: - Bezier curves

    func testScaleCurveMonotonicLightness() {
        let scale = ScaleCurve.primary.apply(hueDegrees: 270)
        for i in 0..<10 {
            XCTAssertGreaterThan(scale[i].luminance, scale[i + 1].luminance)
        }
    }

    func testHandleMagnitudeChangesDistribution() {
        // Zero magnitude collapses to piecewise linear; non-zero
        // bends the curve so interior steps differ.
        let linear = ScaleCurve(
            start: (0.9, 0.05), cusp: (0.5, 0.2), end: (0.2, 0.1),
            handleMagnitude: 0
        ).apply(hueDegrees: 30)
        let bent = ScaleCurve(
            start: (0.9, 0.05), cusp: (0.5, 0.2), end: (0.2, 0.1),
            handleMagnitude: 0.4
        ).apply(hueDegrees: 30)

        // Anchors (s0/s5/s10) coincide; interior steps differ.
        XCTAssertEqual(linear.s0, bent.s0)
        XCTAssertEqual(linear.s5, bent.s5)
        XCTAssertEqual(linear.s10, bent.s10)
        XCTAssertNotEqual(linear.s2, bent.s2)
    }

    func testMirrorBezierAnchorsExact() {
        // s0/s5/s10 must match the input anchors exactly — the curve
        // doesn't drift through them.
        let curve = ScaleCurve(
            start: (0.9, 0.05), cusp: (0.5, 0.2), end: (0.2, 0.1),
            handleMagnitude: 0.4
        )
        let scale = curve.apply(hueDegrees: 0)
        XCTAssertEqual(scale.s0, Color(oklch: OkLch(0.9, 0.05, 0)))
        XCTAssertEqual(scale.s5, Color(oklch: OkLch(0.5, 0.2, 0)))
        XCTAssertEqual(scale.s10, Color(oklch: OkLch(0.2, 0.1, 0)))
    }

    // MARK: - Seed-driven palette

    func testSeedDrivenPaletteRotatesAllHues() {
        // A red-orange seed (hue ≈ 40°) should rotate the palette so
        // that "red" lands near 40° instead of the default 30°.
        let seed = Color(oklch: OkLch(0.6, 0.18, 40 * .pi / 180))
        let palette = ColorPalette.generate(seed: seed)

        let seedDeg = seed.oklch.h * 180 / .pi
        XCTAssertEqual(palette.red.angle, seedDeg, accuracy: 0.5)
    }

    func testSeedDrivenPalettePreservesSpacing() {
        // Rigid rotation preserves relative angles between hues.
        let defaults: [Hue: Double] = .defaultHueAngles
        let defaultSpacing = defaults[.orange]! - defaults[.red]!  // 30°

        let seed = Color(oklch: OkLch(0.6, 0.18, 100 * .pi / 180))
        let palette = ColorPalette.generate(seed: seed)
        let rotatedSpacing = palette.orange.angle - palette.red.angle
        XCTAssertEqual(rotatedSpacing, defaultSpacing, accuracy: 0.001)
    }

    func testSeedDrivenThemeUsesCoherentPalette() {
        // The factory routes a non-nil brand through generate(seed:),
        // so palette hues should be rotated relative to defaults.
        let seed = Color(oklch: OkLch(0.6, 0.18, 15 * .pi / 180))  // crimson-ish
        let theme = ColorTheme.light(brand: seed)

        // Red should have rotated toward the seed, not stayed at 30°.
        XCTAssertNotEqual(theme.palette.red.angle, 30, accuracy: 1)
    }

    // MARK: - ColorTheme factories

    func testLightThemeSurfacesAreBright() {
        let theme = ColorTheme.light()
        XCTAssertGreaterThan(theme.surface.primary.luminance, 0.8)
        XCTAssertLessThan(theme.label.primary.luminance, 0.3)
    }

    func testDarkThemeSurfacesAreDark() {
        let theme = ColorTheme.dark()
        XCTAssertLessThan(theme.surface.primary.luminance, 0.3)
        XCTAssertGreaterThan(theme.label.primary.luminance, 0.8)
    }

    func testThemeUsesProvidedBrandColor() {
        let brand = Color(1, 0.4, 0.2)  // distinctive orange
        let theme = ColorTheme.light(brand: brand)
        // Should preserve the original RGB (not the inverse override).
        XCTAssertEqual(theme.brand.primary.red, brand.red)
        XCTAssertEqual(theme.brand.primary.green, brand.green)
        XCTAssertEqual(theme.brand.primary.blue, brand.blue)
        // Should have inverse populated.
        XCTAssertEqual(theme.brand.primary.inverse, .white)
    }

    func testStatusTokensPopulated() {
        let theme = ColorTheme.light()
        // Rough sanity: success is greenish, error is reddish.
        XCTAssertGreaterThan(theme.status.success.primary.green, theme.status.success.primary.red)
        XCTAssertGreaterThan(theme.status.error.primary.red, theme.status.error.primary.green)
    }

    func testThemeCopyOverridesBrand() {
        let base = ColorTheme.light()
        let customBrand = Color(0.5, 0, 1).withInverse(.white)
        let custom = base.copy {
            $0.brand.primary = customBrand
        }
        XCTAssertEqual(custom.brand.primary, customBrand)
        XCTAssertEqual(custom.label.primary, base.label.primary)  // unchanged
    }

    // MARK: - Integration with Provider

    func testThemeInjectableViaProvider() throws {
        let theme = ColorTheme.light(brand: Color(1, 0.4, 0.2))
        var observed: Color? = nil
        let tree = Provided(theme) {
            Buildable { ctx in
                observed = ctx.read(ColorTheme.self).brand.primary
                return TestLeaf(label: "")
            }
        }
        _ = Node.inflate(tree)
        let red = try XCTUnwrap(observed?.red)
        XCTAssertEqual(red, 1, accuracy: 0.001)
    }
}

#endif
