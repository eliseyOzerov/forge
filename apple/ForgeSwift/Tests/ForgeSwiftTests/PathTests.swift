import XCTest
@testable import ForgeSwift

final class PathTests: XCTestCase {

    // MARK: - Empty Path

    func testEmptyPath() {
        let p = Path()
        XCTAssertTrue(p.isEmpty)
        XCTAssertEqual(p.length, 0)
        XCTAssertNil(p.tangent(at: 0))
        XCTAssertNil(p.point(at: 0))
        XCTAssertTrue(p.sample(count: 5).isEmpty)
    }

    // MARK: - Building

    func testMoveAndLine() {
        var p = Path()
        p.move(to: Point(0, 0))
        p.line(to: Point(10, 0))
        XCTAssertFalse(p.isEmpty)
        XCTAssertEqual(p.currentPoint, Point(10, 0))
    }

    func testClose() {
        var p = Path()
        p.move(to: Point(0, 0))
        p.line(to: Point(10, 0))
        p.line(to: Point(10, 10))
        p.close()
        XCTAssertEqual(p.currentPoint, Point(0, 0))
    }

    func testAddRect() {
        var p = Path()
        p.addRect(Rect(x: 10, y: 20, width: 100, height: 50))
        let bb = p.boundingBox
        XCTAssertEqual(bb.x, 10, accuracy: 1e-5)
        XCTAssertEqual(bb.y, 20, accuracy: 1e-5)
        XCTAssertEqual(bb.width, 100, accuracy: 1e-5)
        XCTAssertEqual(bb.height, 50, accuracy: 1e-5)
    }

    func testAddEllipse() {
        var p = Path()
        p.addEllipse(in: Rect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertFalse(p.isEmpty)
        XCTAssertTrue(p.contains(Point(50, 50)))
        XCTAssertFalse(p.contains(Point(0, 0)))
    }

    func testAddPath() {
        var p1 = Path()
        p1.move(to: Point(0, 0))
        p1.line(to: Point(10, 0))

        var p2 = Path()
        p2.move(to: Point(20, 0))
        p2.line(to: Point(30, 0))

        p1.addPath(p2)
        let bb = p1.boundingBox
        XCTAssertEqual(bb.right, 30, accuracy: 1e-5)
    }

    // MARK: - Constructors

    func testLineConstructor() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        XCTAssertEqual(p.length, 100, accuracy: 1e-5)
    }

    func testPolylineEmpty() {
        let p = Path.polyline([])
        XCTAssertTrue(p.isEmpty)
    }

    func testPolyline() {
        let p = Path.polyline([Point(0, 0), Point(10, 0), Point(10, 10)])
        XCTAssertEqual(p.length, 20, accuracy: 1e-5)
    }

    func testPolygon() {
        let p = Path.polygon([Point(0, 0), Point(10, 0), Point(10, 10)])
        // Triangle: 10 + 10 + sqrt(200)
        let expected = 10 + 10 + sqrt(200.0)
        XCTAssertEqual(p.length, expected, accuracy: 1e-3)
    }

    func testBezierInvalidCounts() {
        XCTAssertTrue(Path.bezier([]).isEmpty)
        XCTAssertTrue(Path.bezier([Point(0, 0)]).isEmpty)
        XCTAssertTrue(Path.bezier([Point(0, 0), Point(1, 1), Point(2, 2)]).isEmpty)
    }

    func testBezierValid() {
        let p = Path.bezier([
            Point(0, 0), Point(0, 10), Point(10, 10), Point(10, 0)
        ])
        XCTAssertFalse(p.isEmpty)
        XCTAssertGreaterThan(p.length, 0)
    }

    func testArcConstructor() {
        let p = Path.arc(in: Rect(x: 0, y: 0, width: 100, height: 100), startAngle: 0, sweepAngle: .pi * 2)
        XCTAssertFalse(p.isEmpty)
        // Full circle, radius 50, circumference ≈ 314
        XCTAssertEqual(p.length, .pi * 100, accuracy: 1)
    }

    func testSpiral() {
        let p = Path.spiral(in: Rect(x: 0, y: 0, width: 100, height: 100), turns: 1, samples: 100)
        XCTAssertFalse(p.isEmpty)
        XCTAssertGreaterThan(p.length, 0)
    }

    // MARK: - Queries

    func testBoundingBox() {
        let p = Path.polygon([Point(10, 20), Point(50, 20), Point(50, 60), Point(10, 60)])
        let bb = p.boundingBox
        XCTAssertEqual(bb.x, 10, accuracy: 1e-5)
        XCTAssertEqual(bb.y, 20, accuracy: 1e-5)
        XCTAssertEqual(bb.width, 40, accuracy: 1e-5)
        XCTAssertEqual(bb.height, 40, accuracy: 1e-5)
    }

    func testContainsInside() {
        var p = Path()
        p.addRect(Rect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(p.contains(Point(50, 50)))
    }

    func testContainsOutside() {
        var p = Path()
        p.addRect(Rect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertFalse(p.contains(Point(150, 50)))
    }

    // MARK: - Derived Paths

    func testDashed() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        let dashed = p.dashed(lengths: [10, 5])
        XCTAssertFalse(dashed.isEmpty)
    }

    func testStroked() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        let stroked = p.stroked(width: 10)
        XCTAssertFalse(stroked.isEmpty)
        // Stroked line becomes a rectangle — should contain points above/below
        XCTAssertTrue(stroked.contains(Point(50, 3)))
        XCTAssertTrue(stroked.contains(Point(50, -3)))
        XCTAssertFalse(stroked.contains(Point(50, 10)))
    }

    func testTransformed() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let translated = p.transformed(CGAffineTransform(translationX: 100, y: 200))
        let bb = translated.boundingBox
        XCTAssertEqual(bb.x, 100, accuracy: 1e-5)
        XCTAssertEqual(bb.y, 200, accuracy: 1e-5)
    }

    // MARK: - Length

    func testLengthStraightLine() {
        let p = Path.line(from: Point(0, 0), to: Point(3, 4))
        XCTAssertEqual(p.length, 5, accuracy: 1e-5)
    }

    func testLengthMultiSegment() {
        let p = Path.polyline([Point(0, 0), Point(10, 0), Point(10, 10)])
        XCTAssertEqual(p.length, 20, accuracy: 1e-5)
    }

    func testLengthClosedSquare() {
        let p = Path.polygon([Point(0, 0), Point(10, 0), Point(10, 10), Point(0, 10)])
        XCTAssertEqual(p.length, 40, accuracy: 1e-5)
    }

    func testLengthCurve() {
        // Cubic bezier — length should be > straight distance
        let p = Path.bezier([
            Point(0, 0), Point(0, 50), Point(100, 50), Point(100, 0)
        ])
        XCTAssertGreaterThan(p.length, 100)
    }

    // MARK: - Tangent

    func testTangentAtStart() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let t = p.tangent(at: 0)
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.point.x, 0, accuracy: 1e-5)
        XCTAssertEqual(t!.point.y, 0, accuracy: 1e-5)
        XCTAssertEqual(t!.angle, 0, accuracy: 1e-5)
    }

    func testTangentAtMiddle() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let t = p.tangent(at: 5)
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.point.x, 5, accuracy: 1e-5)
        XCTAssertEqual(t!.point.y, 0, accuracy: 1e-5)
    }

    func testTangentAtEnd() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let t = p.tangent(at: 10)
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.point.x, 10, accuracy: 1e-5)
    }

    func testTangentPastEnd() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let t = p.tangent(at: 20)
        XCTAssertNotNil(t)
        XCTAssertEqual(t!.point.x, 10, accuracy: 1e-5)
    }

    func testTangentDirection() {
        let p = Path.line(from: Point(0, 0), to: Point(0, 10))
        let t = p.tangent(at: 5)!
        XCTAssertEqual(t.direction.x, 0, accuracy: 1e-5)
        XCTAssertEqual(t.direction.y, 1, accuracy: 1e-5)
    }

    func testTangentNormal() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let t = p.tangent(at: 5)!
        XCTAssertEqual(t.normal.x, 0, accuracy: 1e-5)
        XCTAssertEqual(t.normal.y, 1, accuracy: 1e-5)
    }

    func testTangentEmpty() {
        XCTAssertNil(Path().tangent(at: 0))
    }

    // MARK: - Point

    func testPointAt() {
        let p = Path.line(from: Point(0, 0), to: Point(10, 0))
        let pt = p.point(at: 7)
        XCTAssertNotNil(pt)
        XCTAssertEqual(pt!.x, 7, accuracy: 1e-5)
    }

    // MARK: - Sample

    func testSampleCount() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        let samples = p.sample(count: 11)
        XCTAssertEqual(samples.count, 11)
    }

    func testSampleSpacing() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        let samples = p.sample(count: 3)
        XCTAssertEqual(samples[0].point.x, 0, accuracy: 1e-5)
        XCTAssertEqual(samples[1].point.x, 50, accuracy: 1e-5)
        XCTAssertEqual(samples[2].point.x, 100, accuracy: 1e-5)
    }

    func testSampleCountOne() {
        let p = Path.line(from: Point(0, 0), to: Point(100, 0))
        let samples = p.sample(count: 1)
        XCTAssertEqual(samples.count, 1)
    }

    func testSampleEmpty() {
        let samples = Path().sample(count: 5)
        XCTAssertTrue(samples.isEmpty)
    }

    // MARK: - Boolean Ops

    @available(iOS 16.0, macOS 13.0, *)
    func testUnion() {
        var a = Path(); a.addRect(Rect(x: 0, y: 0, width: 50, height: 50))
        var b = Path(); b.addRect(Rect(x: 25, y: 25, width: 50, height: 50))
        let u = a.union(b)
        XCTAssertTrue(u.contains(Point(10, 10)))
        XCTAssertTrue(u.contains(Point(60, 60)))
    }

    @available(iOS 16.0, macOS 13.0, *)
    func testSubtracting() {
        var a = Path(); a.addRect(Rect(x: 0, y: 0, width: 100, height: 100))
        var b = Path(); b.addRect(Rect(x: 25, y: 25, width: 50, height: 50))
        let s = a.subtracting(b)
        XCTAssertTrue(s.contains(Point(10, 10)))
        XCTAssertFalse(s.contains(Point(50, 50)))
    }

    @available(iOS 16.0, macOS 13.0, *)
    func testIntersection() {
        var a = Path(); a.addRect(Rect(x: 0, y: 0, width: 50, height: 50))
        var b = Path(); b.addRect(Rect(x: 25, y: 25, width: 50, height: 50))
        let i = a.intersection(b)
        XCTAssertTrue(i.contains(Point(30, 30)))
        XCTAssertFalse(i.contains(Point(10, 10)))
    }
}
