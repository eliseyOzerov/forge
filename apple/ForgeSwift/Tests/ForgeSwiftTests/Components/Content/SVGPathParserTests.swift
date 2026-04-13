#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

final class SVGPathParserTests: XCTestCase {

    // MARK: - Empty / Minimal

    func testEmptyString() {
        let path = SVGPathDataParser.parse("")
        XCTAssertTrue(path.isEmpty)
    }

    func testMoveOnly() {
        let path = SVGPathDataParser.parse("M10 20")
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.currentPoint, Point(10, 20))
    }

    // MARK: - LineTo

    func testLineTo() {
        let path = SVGPathDataParser.parse("M0 0 L100 0")
        XCTAssertEqual(path.length, 100, accuracy: 1e-3)
    }

    func testRelativeLineTo() {
        let path = SVGPathDataParser.parse("M10 10 l90 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
        XCTAssertEqual(path.length, 90, accuracy: 1e-3)
    }

    // MARK: - Horizontal / Vertical

    func testHorizontalLineTo() {
        let path = SVGPathDataParser.parse("M0 0 H50")
        XCTAssertEqual(path.currentPoint, Point(50, 0))
        XCTAssertEqual(path.length, 50, accuracy: 1e-3)
    }

    func testRelativeHorizontal() {
        let path = SVGPathDataParser.parse("M10 0 h40")
        XCTAssertEqual(path.currentPoint, Point(50, 0))
    }

    func testVerticalLineTo() {
        let path = SVGPathDataParser.parse("M0 0 V50")
        XCTAssertEqual(path.currentPoint, Point(0, 50))
        XCTAssertEqual(path.length, 50, accuracy: 1e-3)
    }

    func testRelativeVertical() {
        let path = SVGPathDataParser.parse("M0 10 v40")
        XCTAssertEqual(path.currentPoint, Point(0, 50))
    }

    // MARK: - Close

    func testClose() {
        let path = SVGPathDataParser.parse("M0 0 L100 0 L100 100 Z")
        // Triangle: 100 + 100 + √(100²+100²)
        let expected = 100 + 100 + sqrt(20000.0)
        XCTAssertEqual(path.length, expected, accuracy: 1)
        XCTAssertEqual(path.currentPoint, Point(0, 0))
    }

    // MARK: - Cubic Bezier

    func testCubicBezier() {
        let path = SVGPathDataParser.parse("M0 0 C0 50 100 50 100 0")
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
        XCTAssertGreaterThan(path.length, 100)
    }

    func testRelativeCubic() {
        let path = SVGPathDataParser.parse("M0 0 c0 50 100 50 100 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
    }

    func testSmoothCubic() {
        let path = SVGPathDataParser.parse("M0 0 C0 50 50 50 50 0 S100 -50 100 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
    }

    // MARK: - Quadratic Bezier

    func testQuadraticBezier() {
        let path = SVGPathDataParser.parse("M0 0 Q50 100 100 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
        XCTAssertGreaterThan(path.length, 100)
    }

    func testSmoothQuadratic() {
        let path = SVGPathDataParser.parse("M0 0 Q50 50 100 0 T200 0")
        XCTAssertEqual(path.currentPoint.x, 200, accuracy: 1e-3)
    }

    // MARK: - Arc

    func testArc() {
        // Semicircle from (0,0) to (100,0) with radius 50
        let path = SVGPathDataParser.parse("M0 0 A50 50 0 0 1 100 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
        // Semicircle length ≈ π * 50 ≈ 157
        XCTAssertEqual(path.length, .pi * 50, accuracy: 5)
    }

    func testRelativeArc() {
        let path = SVGPathDataParser.parse("M0 0 a50 50 0 0 1 100 0")
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
    }

    func testLargeArcFlag() {
        let path = SVGPathDataParser.parse("M0 0 A50 50 0 1 1 100 0")
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.currentPoint.x, 100, accuracy: 1e-3)
        XCTAssertGreaterThan(path.length, 0)
    }

    // MARK: - Implicit Repetition

    func testImplicitLineAfterMove() {
        // After M, subsequent coordinate pairs are treated as L
        let path = SVGPathDataParser.parse("M0 0 100 0 100 100")
        XCTAssertEqual(path.length, 200, accuracy: 1e-3)
    }

    func testImplicitRepeatedLine() {
        let path = SVGPathDataParser.parse("M0 0 L50 0 100 0")
        XCTAssertEqual(path.currentPoint, Point(100, 0))
        XCTAssertEqual(path.length, 100, accuracy: 1e-3)
    }

    // MARK: - Complex Paths

    func testSquarePath() {
        let path = SVGPathDataParser.parse("M0 0 L100 0 L100 100 L0 100 Z")
        XCTAssertEqual(path.length, 400, accuracy: 1e-3)
    }

    func testMixedCommands() {
        let path = SVGPathDataParser.parse("M10 10 H90 V90 H10 Z")
        XCTAssertEqual(path.length, 320, accuracy: 1e-3)
    }

    // MARK: - Tokenizer Edge Cases

    func testNegativeNumbers() {
        let path = SVGPathDataParser.parse("M-10-20 L-30-40")
        XCTAssertEqual(path.currentPoint, Point(-30, -40))
    }

    func testScientificNotation() {
        let path = SVGPathDataParser.parse("M1e1 2e1 L3e1 4e1")
        XCTAssertEqual(path.currentPoint.x, 30, accuracy: 1e-3)
        XCTAssertEqual(path.currentPoint.y, 40, accuracy: 1e-3)
    }

    func testDecimalWithoutLeadingZero() {
        let path = SVGPathDataParser.parse("M.5.5 L1.5 1.5")
        XCTAssertEqual(path.currentPoint.x, 1.5, accuracy: 1e-3)
    }

    func testCommaAndSpaceSeparators() {
        let p1 = SVGPathDataParser.parse("M0,0 L100,0")
        let p2 = SVGPathDataParser.parse("M0 0 L100 0")
        XCTAssertEqual(p1.length, p2.length, accuracy: 1e-3)
    }
}

#endif
