import XCTest
@testable import ForgeSwift

final class DragTransformTests: XCTestCase {

    private let acc = 0.01

    // MARK: - Axis

    func testHorizontalZeroesY() {
        let result = DragTransform.horizontal(Vec2(5, 10))
        XCTAssertEqual(result.x, 5, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testVerticalZeroesX() {
        let result = DragTransform.vertical(Vec2(5, 10))
        XCTAssertEqual(result.x, 0, accuracy: acc)
        XCTAssertEqual(result.y, 10, accuracy: acc)
    }

    // MARK: - Rect Clamp

    func testRectClampInside() {
        let t = DragTransform.clamp(to: Rect(x: 0, y: 0, width: 100, height: 100))
        let result = t(Vec2(50, 50))
        XCTAssertEqual(result.x, 50, accuracy: acc)
        XCTAssertEqual(result.y, 50, accuracy: acc)
    }

    func testRectClampOutside() {
        let t = DragTransform.clamp(to: Rect(x: 0, y: 0, width: 100, height: 100))
        let result = t(Vec2(150, -20))
        XCTAssertEqual(result.x, 100, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testRectClampWithOffset() {
        let t = DragTransform.clamp(to: Rect(x: 10, y: 20, width: 50, height: 30))
        let result = t(Vec2(0, 100))
        XCTAssertEqual(result.x, 10, accuracy: acc)
        XCTAssertEqual(result.y, 50, accuracy: acc)
    }

    // MARK: - Disc Clamp

    func testDiscClampInside() {
        let t = DragTransform.disc(center: Vec2(50, 50), radius: 30)
        let result = t(Vec2(60, 60))
        XCTAssertEqual(result.x, 60, accuracy: acc)
        XCTAssertEqual(result.y, 60, accuracy: acc)
    }

    func testDiscClampOutside() {
        let t = DragTransform.disc(center: Vec2(0, 0), radius: 10)
        let result = t(Vec2(20, 0))
        XCTAssertEqual(result.x, 10, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    // MARK: - Line Clamp

    func testLineProjectsMidpoint() {
        let t = DragTransform.line(from: Vec2(0, 0), to: Vec2(100, 0))
        let result = t(Vec2(50, 30)) // 30 above the line at x=50
        XCTAssertEqual(result.x, 50, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testLineClampsToStart() {
        let t = DragTransform.line(from: Vec2(0, 0), to: Vec2(100, 0))
        let result = t(Vec2(-50, 0))
        XCTAssertEqual(result.x, 0, accuracy: acc)
    }

    func testLineClampsToEnd() {
        let t = DragTransform.line(from: Vec2(0, 0), to: Vec2(100, 0))
        let result = t(Vec2(200, 0))
        XCTAssertEqual(result.x, 100, accuracy: acc)
    }

    func testLineDiagonal() {
        let t = DragTransform.line(from: Vec2(0, 0), to: Vec2(10, 10))
        let result = t(Vec2(5, 0)) // project onto diagonal
        XCTAssertEqual(result.x, 2.5, accuracy: acc)
        XCTAssertEqual(result.y, 2.5, accuracy: acc)
    }

    // MARK: - Points Snap

    func testSnapToNearest() {
        let points = [Vec2(0, 0), Vec2(100, 0), Vec2(50, 50)]
        let t = DragTransform.snap(to: points)
        let result = t(Vec2(48, 47))
        XCTAssertEqual(result.x, 50, accuracy: acc)
        XCTAssertEqual(result.y, 50, accuracy: acc)
    }

    func testSnapEmptyPoints() {
        let t = DragTransform.snap(to: [])
        let result = t(Vec2(10, 20))
        XCTAssertEqual(result.x, 10, accuracy: acc)
        XCTAssertEqual(result.y, 20, accuracy: acc)
    }

    // MARK: - Grid Snap

    func testGridSnap() {
        let t = DragTransform.grid(cellSize: Vec2(10, 10))
        let result = t(Vec2(13, 27))
        XCTAssertEqual(result.x, 10, accuracy: acc)
        XCTAssertEqual(result.y, 30, accuracy: acc)
    }

    // MARK: - Path Snap

    func testPathSnapToLine() {
        var p = Path()
        p.move(to: Point(0, 0))
        p.line(to: Point(100, 0))
        let t = DragTransform.path(p, samples: 50)
        let result = t(Vec2(50, 30))
        XCTAssertEqual(result.y, 0, accuracy: 3) // should be near y=0
        XCTAssertEqual(result.x, 50, accuracy: 3)
    }

    // MARK: - Magnet

    func testMagnetPullsToward() {
        let snap = DragTransform.snap(to: [Vec2(100, 0)])
        let t = DragTransform.magnet(snap, strength: 0.5)
        let result = t(Vec2(0, 0))
        // Pulled halfway toward (100, 0)
        XCTAssertEqual(result.x, 50, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testMagnetOutsideRadius() {
        let snap = DragTransform.snap(to: [Vec2(100, 0)])
        let t = DragTransform.magnet(snap, strength: 1.0, radius: 10)
        let result = t(Vec2(0, 0)) // 100 away, radius is 10
        // Outside radius → unchanged
        XCTAssertEqual(result.x, 0, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testMagnetInsideRadius() {
        let snap = DragTransform.snap(to: [Vec2(100, 0)])
        let t = DragTransform.magnet(snap, strength: 1.0, radius: 200)
        let result = t(Vec2(0, 0)) // within radius
        XCTAssertEqual(result.x, 100, accuracy: acc) // strength=1 → full snap
    }

    // MARK: - Sequence

    func testSequenceChains() {
        let t = DragTransform.sequence([
            .horizontal,                              // zero y
            .clamp(to: Rect(x: 0, y: 0, width: 50, height: 50))  // clamp x to 0...50
        ])
        let result = t(Vec2(80, 30))
        XCTAssertEqual(result.x, 50, accuracy: acc)
        XCTAssertEqual(result.y, 0, accuracy: acc)
    }

    func testSequenceEmpty() {
        let t = DragTransform.sequence([])
        let result = t(Vec2(10, 20))
        XCTAssertEqual(result.x, 10, accuracy: acc)
        XCTAssertEqual(result.y, 20, accuracy: acc)
    }
}
