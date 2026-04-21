import XCTest
@testable import ForgeSwift

final class ShapeTests: XCTestCase {

    let unit = Rect(x: 0, y: 0, width: 100, height: 100)
    let wide = Rect(x: 0, y: 0, width: 200, height: 100)
    let offset = Rect(x: 50, y: 50, width: 100, height: 100)

    // MARK: - Constructors

    func testRect() {
        let path = AnyShape.rect().path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        XCTAssertFalse(path.contains(Point(-1, -1)))
        XCTAssertEqual(path.boundingBox.width, 100, accuracy: 1e-5)
        XCTAssertEqual(path.boundingBox.height, 100, accuracy: 1e-5)
    }

    func testRectOffset() {
        let path = AnyShape.rect().path(in: offset)
        XCTAssertTrue(path.contains(Point(100, 100)))
        XCTAssertFalse(path.contains(Point(0, 0)))
    }

    func testRoundedRect() {
        let path = AnyShape.roundedRect(radius: 10).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        // Corner should be rounded — point at exact corner is outside
        XCTAssertFalse(path.contains(Point(1, 1)))
    }

    func testEllipse() {
        let path = AnyShape.ellipse().path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        // Corners of bounding rect should be outside ellipse
        XCTAssertFalse(path.contains(Point(1, 1)))
    }

    func testCircleInSquare() {
        let path = AnyShape.circle().path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        XCTAssertFalse(path.contains(Point(1, 1)))
    }

    func testCircleInWideRect() {
        let path = AnyShape.circle().path(in: wide)
        let bb = path.boundingBox
        // Circle should be 100x100 centered in 200x100
        XCTAssertEqual(bb.width, 100, accuracy: 1)
        XCTAssertEqual(bb.height, 100, accuracy: 1)
    }

    func testCapsuleSquare() {
        let path = AnyShape.capsule().path(in: unit)
        // Capsule in square = circle
        XCTAssertTrue(path.contains(Point(50, 50)))
    }

    func testCapsuleWide() {
        let path = AnyShape.capsule().path(in: wide)
        // Pill shape — center is inside, far corners outside
        XCTAssertTrue(path.contains(Point(100, 50)))
        XCTAssertFalse(path.contains(Point(1, 1)))
    }

    func testRegularTriangle() {
        let path = AnyShape.regular(sides: 3).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        XCTAssertFalse(path.isEmpty)
    }

    func testRegularSquare() {
        let verts = AnyShape.regular(sides: 4, rotation: -.pi / 4).vertices(in: unit)
        XCTAssertEqual(verts.count, 4)
    }

    func testRegularHexagon() {
        let path = AnyShape.regular(sides: 6).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
    }

    func testStar5() {
        let path = AnyShape.star(points: 5).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        let verts = AnyShape.star(points: 5).vertices(in: unit)
        XCTAssertEqual(verts.count, 10) // 5 outer + 5 inner
    }

    func testStarInnerRadius() {
        let narrow = AnyShape.star(points: 5, innerRadius: 0.1).path(in: unit)
        let wide = AnyShape.star(points: 5, innerRadius: 0.9).path(in: unit)
        // Narrower star has less area — check a point between inner/outer
        // Just verify both resolve without error
        XCTAssertFalse(narrow.isEmpty)
        XCTAssertFalse(wide.isEmpty)
    }

    func testPolygonRelative() {
        // Triangle taking top-left, top-right, bottom-center
        let path = AnyShape.polygon([Point(0, 0), Point(1, 0), Point(0.5, 1)]).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        XCTAssertFalse(path.contains(Point(90, 90)))
    }

    // MARK: - Vertices

    func testRectVertices() {
        let verts = AnyShape.rect().vertices(in: unit)
        XCTAssertEqual(verts.count, 4)
        XCTAssertEqual(verts[0], Point(0, 0))
        XCTAssertEqual(verts[1], Point(100, 0))
        XCTAssertEqual(verts[2], Point(100, 100))
        XCTAssertEqual(verts[3], Point(0, 100))
    }

    func testVertexShapeAutoPath() {
        // Shape from vertices — path is a closed polygon of those vertices
        let verts: (Rect) -> [Point] = { rect in
            [Point(rect.x, rect.y), Point(rect.right, rect.y), Point(rect.midX, rect.bottom)]
        }
        let shape = CustomShape({ rect in Path.polygon(verts(rect)) }, vertices: verts)
        let path = shape.path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
    }

    func testVerticesExtractedFromPath() {
        // Path-only shape — vertices extracted via heuristic
        let shape = CustomShape({ rect in
            Path.polygon([Point(rect.x, rect.y), Point(rect.right, rect.y), Point(rect.right, rect.bottom)])
        })
        let verts = shape.vertices(in: unit)
        XCTAssertGreaterThanOrEqual(verts.count, 3)
    }

    // MARK: - Modifiers: Round

    func testRoundRadius() {
        let sharp = AnyShape.rect().path(in: unit)
        let rounded = AnyShape.rect().round(radius: 20).path(in: unit)
        // Corner point (2,2) is inside sharp rect but outside rounded
        XCTAssertTrue(sharp.contains(Point(2, 2)))
        XCTAssertFalse(rounded.contains(Point(2, 2)))
        // Center still inside
        XCTAssertTrue(rounded.contains(Point(50, 50)))
    }

    func testRoundSmooth() {
        let circular = AnyShape.rect().round(radius: 20, smooth: 0).path(in: unit)
        let squircle = AnyShape.rect().round(radius: 20, smooth: 1).path(in: unit)
        // Both should contain center
        XCTAssertTrue(circular.contains(Point(50, 50)))
        XCTAssertTrue(squircle.contains(Point(50, 50)))
    }

    func testRoundPerVertexRadii() {
        // Alternating: 20, 0, 20, 0
        let path = AnyShape.rect().round(radii: [20, 0, 20, 0]).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        // Top-left (0-radius) should be sharp
        XCTAssertFalse(path.contains(Point(2, 2)))
        // Top-right (0-radius) should be sharp — wait, radii cycle: [20, 0, 20, 0]
        // vertex 0 = TL gets 20, vertex 1 = TR gets 0
        XCTAssertTrue(path.contains(Point(98, 2))) // TR sharp corner — inside
    }

    func testRoundZeroRadius() {
        let path = AnyShape.rect().round(radius: 0).path(in: unit)
        XCTAssertTrue(path.contains(Point(2, 2))) // corners still sharp
    }

    // MARK: - Modifiers: Chamfer

    func testChamfer() {
        let path = AnyShape.rect().chamfer(size: 20).path(in: unit)
        XCTAssertTrue(path.contains(Point(50, 50)))
        XCTAssertFalse(path.contains(Point(2, 2))) // corner cut
    }

    // MARK: - Modifiers: Transform

    func testScale() {
        let path = AnyShape.rect().scaled(0.5).path(in: unit)
        let bb = path.boundingBox
        XCTAssertEqual(bb.width, 50, accuracy: 1)
        XCTAssertEqual(bb.height, 50, accuracy: 1)
    }

    func testScaleNonUniform() {
        let path = AnyShape.rect().scaled(2, 0.5).path(in: unit)
        let bb = path.boundingBox
        XCTAssertEqual(bb.width, 200, accuracy: 1)
        XCTAssertEqual(bb.height, 50, accuracy: 1)
    }

    func testRotate() {
        let path = AnyShape.rect().rotated(.pi / 4).path(in: unit)
        // Rotated square has larger bounding box
        let bb = path.boundingBox
        XCTAssertGreaterThan(bb.width, 100)
    }

    func testTranslate() {
        let path = AnyShape.rect().translated(50, 50).path(in: unit)
        let bb = path.boundingBox
        XCTAssertEqual(bb.x, 50, accuracy: 1)
        XCTAssertEqual(bb.y, 50, accuracy: 1)
    }

    func testInset() {
        let path = AnyShape.rect().inset(10).path(in: unit)
        let bb = path.boundingBox
        XCTAssertEqual(bb.width, 80, accuracy: 1)
        XCTAssertEqual(bb.height, 80, accuracy: 1)
    }

    func testOutset() {
        let path = AnyShape.rect().outset(10).path(in: unit)
        let bb = path.boundingBox
        XCTAssertEqual(bb.width, 120, accuracy: 1)
        XCTAssertEqual(bb.height, 120, accuracy: 1)
    }

    // MARK: - Boolean Ops

    @available(iOS 16.0, macOS 13.0, *)
    func testUnion() {
        let a = AnyShape.rect()
        let b = AnyShape.rect().translated(50, 0)
        let u = a.union(b).path(in: unit)
        XCTAssertTrue(u.contains(Point(10, 50)))
        XCTAssertTrue(u.contains(Point(140, 50)))
    }

    @available(iOS 16.0, macOS 13.0, *)
    func testSubtract() {
        let a = AnyShape.rect()
        let b = AnyShape.circle()
        let s = a.subtract(b).path(in: unit)
        // Corner should remain (outside circle)
        XCTAssertTrue(s.contains(Point(5, 5)))
        // Center should be gone (inside circle)
        XCTAssertFalse(s.contains(Point(50, 50)))
    }

    @available(iOS 16.0, macOS 13.0, *)
    func testIntersect() {
        let a = AnyShape.rect()
        let b = AnyShape.circle()
        let i = a.intersect(b).path(in: unit)
        // Center is in both
        XCTAssertTrue(i.contains(Point(50, 50)))
        // Corner is only in rect, not circle
        XCTAssertFalse(i.contains(Point(5, 5)))
    }

    // MARK: - Chaining

    func testModifierChaining() {
        let path = AnyShape.regular(sides: 6)
            .round(radius: 5)
            .scaled(0.8)
            .rotated(.pi / 6)
            .translated(10, 10)
            .path(in: unit)
        XCTAssertFalse(path.isEmpty)
    }
}
