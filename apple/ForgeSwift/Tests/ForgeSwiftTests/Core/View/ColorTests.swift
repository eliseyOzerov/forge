import XCTest
@testable import ForgeSwift

final class ColorTests: XCTestCase {

    private let acc = 0.05

    // MARK: - OkLab roundtrip

    func testOkLabRoundtripRed() {
        let c = Color.red
        let roundtrip = Color(oklab: c.oklab)
        XCTAssertEqual(roundtrip.red, 1, accuracy: acc)
        XCTAssertEqual(roundtrip.green, 0, accuracy: acc)
        XCTAssertEqual(roundtrip.blue, 0, accuracy: acc)
    }

    func testOkLabRoundtripWhite() {
        let c = Color.white
        let lab = c.oklab
        XCTAssertEqual(lab.l, 1, accuracy: acc)
        XCTAssertEqual(lab.a, 0, accuracy: acc)
        XCTAssertEqual(lab.b, 0, accuracy: acc)
    }

    func testOkLabRoundtripBlack() {
        let c = Color.black
        let lab = c.oklab
        XCTAssertEqual(lab.l, 0, accuracy: acc)
    }

    func testOkLabRoundtripArbitrary() {
        let c = Color(0.3, 0.6, 0.9)
        let rt = Color(oklab: c.oklab)
        XCTAssertEqual(rt.red, 0.3, accuracy: acc)
        XCTAssertEqual(rt.green, 0.6, accuracy: acc)
        XCTAssertEqual(rt.blue, 0.9, accuracy: acc)
    }

    // MARK: - OkLch roundtrip

    func testOkLchRoundtripRed() {
        let c = Color.red
        let rt = Color(oklch: c.oklch)
        XCTAssertEqual(rt.red, 1, accuracy: acc)
        XCTAssertEqual(rt.green, 0, accuracy: acc)
        XCTAssertEqual(rt.blue, 0, accuracy: acc)
    }

    func testOkLchAchromaticHasZeroChroma() {
        let lch = Color.gray.oklch
        XCTAssertEqual(lch.c, 0, accuracy: 0.01)
    }

    // MARK: - HSV roundtrip

    func testHSVRoundtripRed() {
        let c = Color.red
        let hsv = c.hsv
        XCTAssertEqual(hsv.h, 0, accuracy: 1)
        XCTAssertEqual(hsv.s, 1, accuracy: acc)
        XCTAssertEqual(hsv.v, 1, accuracy: acc)
        let rt = Color(hsv: hsv)
        XCTAssertEqual(rt.red, 1, accuracy: acc)
    }

    func testHSVRoundtripGreen() {
        let c = Color.green
        let hsv = c.hsv
        XCTAssertEqual(hsv.h, 120, accuracy: 1)
    }

    func testHSVRoundtripBlue() {
        let c = Color.blue
        let hsv = c.hsv
        XCTAssertEqual(hsv.h, 240, accuracy: 1)
    }

    // MARK: - HSL roundtrip

    func testHSLRoundtripRed() {
        let c = Color.red
        let hsl = c.hsl
        XCTAssertEqual(hsl.h, 0, accuracy: 1)
        XCTAssertEqual(hsl.s, 1, accuracy: acc)
        XCTAssertEqual(hsl.l, 0.5, accuracy: acc)
    }

    // MARK: - Lerp

    func testLerpOkLabMidpoint() {
        let mid = Color.black.lerp(to: .white, t: 0.5)
        let lab = mid.oklab
        XCTAssertEqual(lab.l, 0.5, accuracy: acc)
    }

    func testLerpEndpoints() {
        let a = Color.red
        let b = Color.blue
        let start = a.lerp(to: b, t: 0)
        let end = a.lerp(to: b, t: 1)
        XCTAssertEqual(start.red, 1, accuracy: acc)
        XCTAssertEqual(end.blue, 1, accuracy: acc)
    }

    func testLerpSRGB() {
        let mid = Color.black.lerp(to: .white, t: 0.5, in: .srgb)
        XCTAssertEqual(mid.red, 0.5, accuracy: acc)
        XCTAssertEqual(mid.green, 0.5, accuracy: acc)
        XCTAssertEqual(mid.blue, 0.5, accuracy: acc)
    }

    // MARK: - Manipulation

    func testDarker() {
        let c = Color(0.5, 0.5, 0.5)
        let d = c.darker(0.5)
        XCTAssertLessThan(d.oklab.l, c.oklab.l)
    }

    func testLighter() {
        let c = Color(0.5, 0.5, 0.5)
        let l = c.lighter(0.5)
        XCTAssertGreaterThan(l.oklab.l, c.oklab.l)
    }

    func testSaturated() {
        let c = Color(0.5, 0.5, 0.5) // gray, no chroma
        let s = c.saturated(0.5)
        XCTAssertGreaterThan(s.oklch.c, c.oklch.c)
    }

    func testDesaturated() {
        let c = Color.red
        let d = c.desaturated(0.5)
        XCTAssertLessThan(d.oklch.c, c.oklch.c)
    }

    func testRotatedChangesHue() {
        let c = Color.red
        let rotated = c.rotated(90)
        // Hue should shift — different color
        XCTAssertNotEqual(c.oklch.h, rotated.oklch.h)
    }

    // MARK: - Harmonies

    func testComplementary() {
        let c = Color.red.complementary()
        XCTAssertNotEqual(c, .red)
    }

    func testTriadicCount() {
        XCTAssertEqual(Color.red.triadic().count, 3)
    }

    func testTetradicCount() {
        XCTAssertEqual(Color.red.tetradic().count, 4)
    }

    func testAnalogousCount() {
        XCTAssertEqual(Color.red.analogous(count: 5).count, 5)
    }

    func testSplitComplementaryCount() {
        XCTAssertEqual(Color.red.splitComplementary().count, 3)
    }

    // MARK: - Palette

    func testShadesGetDarker() {
        let shades = Color.blue.shades(count: 3)
        XCTAssertEqual(shades.count, 3)
        for shade in shades {
            XCTAssertLessThan(shade.oklab.l, Color.blue.oklab.l + 0.01)
        }
    }

    func testTintsGetLighter() {
        let tints = Color.blue.tints(count: 3)
        XCTAssertEqual(tints.count, 3)
        for tint in tints {
            XCTAssertGreaterThan(tint.oklab.l, Color.blue.oklab.l - 0.01)
        }
    }

    func testScaleCount() {
        XCTAssertEqual(Color.red.scale(count: 11).count, 11)
    }

    // MARK: - Constants

    func testGrayConstant() {
        XCTAssertEqual(Color.gray.red, 0.5, accuracy: acc)
        XCTAssertEqual(Color.gray.green, 0.5, accuracy: acc)
        XCTAssertEqual(Color.gray.blue, 0.5, accuracy: acc)
    }

    func testOrangeConstant() {
        let hsv = Color.orange.hsv
        XCTAssertGreaterThan(hsv.h, 20)
        XCTAssertLessThan(hsv.h, 50)
    }
}
