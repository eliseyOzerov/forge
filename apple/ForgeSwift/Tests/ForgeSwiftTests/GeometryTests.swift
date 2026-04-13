import XCTest
@testable import ForgeSwift

final class GeometryTests: XCTestCase {

    // MARK: - Rect

    func testRectFactories() {
        let r = Rect.fromLTRB(10, 20, 110, 70)
        XCTAssertEqual(r.x, 10)
        XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 100)
        XCTAssertEqual(r.height, 50)
    }

    func testRectCorners() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(r.topLeft, Vec2(10, 20))
        XCTAssertEqual(r.topRight, Vec2(110, 20))
        XCTAssertEqual(r.bottomLeft, Vec2(10, 70))
        XCTAssertEqual(r.bottomRight, Vec2(110, 70))
        XCTAssertEqual(r.center, Vec2(60, 45))
    }

    func testRectInset() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        let inset = r.inset(by: 10)
        XCTAssertEqual(inset.x, 10)
        XCTAssertEqual(inset.y, 10)
        XCTAssertEqual(inset.width, 80)
        XCTAssertEqual(inset.height, 80)
    }

    func testRectAsymmetricInset() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        let inset = r.inset(left: 10, top: 20, right: 30, bottom: 40)
        XCTAssertEqual(inset.x, 10)
        XCTAssertEqual(inset.y, 20)
        XCTAssertEqual(inset.width, 60)
        XCTAssertEqual(inset.height, 40)
    }

    func testRectContains() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(r.contains(Vec2(50, 50)))
        XCTAssertFalse(r.contains(Vec2(150, 50)))
    }

    func testRectIntersects() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 50, width: 100, height: 100)
        let c = Rect(x: 200, y: 200, width: 10, height: 10)
        XCTAssertTrue(a.intersects(b))
        XCTAssertFalse(a.intersects(c))
    }

    func testRectUnion() {
        let a = Rect(x: 0, y: 0, width: 50, height: 50)
        let b = Rect(x: 30, y: 30, width: 50, height: 50)
        let u = a.union(b)
        XCTAssertEqual(u.x, 0)
        XCTAssertEqual(u.y, 0)
        XCTAssertEqual(u.width, 80)
        XCTAssertEqual(u.height, 80)
    }

    func testRectNormalize() {
        let r = Rect(x: 100, y: 200, width: 400, height: 300)
        let n = r.normalize(Vec2(300, 350))
        XCTAssertEqual(n.x, 0.5, accuracy: 1e-10)
        XCTAssertEqual(n.y, 0.5, accuracy: 1e-10)
    }

    func testRectDenormalize() {
        let r = Rect(x: 100, y: 200, width: 400, height: 300)
        let d = r.denormalize(Vec2(0.5, 0.5))
        XCTAssertEqual(d.x, 300, accuracy: 1e-10)
        XCTAssertEqual(d.y, 350, accuracy: 1e-10)
    }

    func testRectLerp() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 100, y: 100, width: 200, height: 200)
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.x, 50)
        XCTAssertEqual(mid.y, 50)
        XCTAssertEqual(mid.width, 150)
        XCTAssertEqual(mid.height, 150)
    }

    func testRectFromPoints() {
        let r = Rect.fromPoints([Vec2(10, 20), Vec2(50, 60), Vec2(30, 10)])
        XCTAssertEqual(r.x, 10)
        XCTAssertEqual(r.y, 10)
        XCTAssertEqual(r.width, 40)
        XCTAssertEqual(r.height, 50)
    }

    // MARK: - Size

    func testSize() {
        let s = Size(100, 50)
        XCTAssertEqual(s.shortestSide, 50)
        XCTAssertEqual(s.longestSide, 100)
        XCTAssertEqual(s.area, 5000)
        XCTAssertEqual(s.aspectRatio, 2)
    }

    func testSizeScaled() {
        let s = Size(100, 50).scaled(2)
        XCTAssertEqual(s.width, 200)
        XCTAssertEqual(s.height, 100)
    }

    // MARK: - Alignment

    func testAlignment() {
        XCTAssertEqual(Alignment.center.x, 0)
        XCTAssertEqual(Alignment.center.y, 0)
        XCTAssertEqual(Alignment.topLeft.x, -1)
        XCTAssertEqual(Alignment.topLeft.y, -1)
        XCTAssertTrue(Alignment.center.isCenter)
        XCTAssertFalse(Alignment.topLeft.isCenter)
    }

    // MARK: - Padding

    func testPadding() {
        let p = Padding(all: 10)
        XCTAssertEqual(p.horizontal, 20)
        XCTAssertEqual(p.vertical, 20)
    }

    func testPaddingAsymmetric() {
        let p = Padding(top: 10, bottom: 20, leading: 5, trailing: 15)
        XCTAssertEqual(p.horizontal, 20)
        XCTAssertEqual(p.vertical, 30)
    }
}
