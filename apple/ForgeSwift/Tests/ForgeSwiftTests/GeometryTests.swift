import XCTest
@testable import ForgeSwift

final class GeometryTests: XCTestCase {

    // MARK: - Rect: Factories

    func testRectZero() {
        let r = Rect.zero
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.y, 0)
        XCTAssertEqual(r.width, 0); XCTAssertEqual(r.height, 0)
    }

    func testRectFromLTRB() {
        let r = Rect.fromLTRB(10, 20, 110, 70)
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 100); XCTAssertEqual(r.height, 50)
    }

    func testRectFromCenter() {
        let r = Rect.fromCenter(Vec2(50, 50), width: 100, height: 60)
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 100); XCTAssertEqual(r.height, 60)
    }

    func testRectFromCircle() {
        let r = Rect.fromCircle(center: Vec2(50, 50), radius: 25)
        XCTAssertEqual(r.x, 25); XCTAssertEqual(r.y, 25)
        XCTAssertEqual(r.width, 50); XCTAssertEqual(r.height, 50)
    }

    func testRectFromSize() {
        let r = Rect.fromSize(Size(200, 100))
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.y, 0)
        XCTAssertEqual(r.width, 200); XCTAssertEqual(r.height, 100)
    }

    func testRectFromPoints() {
        let r = Rect.fromPoints([Vec2(10, 20), Vec2(50, 60), Vec2(30, 10)])
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 10)
        XCTAssertEqual(r.width, 40); XCTAssertEqual(r.height, 50)
    }

    func testRectFromPointsEmpty() {
        XCTAssertEqual(Rect.fromPoints([]), .zero)
    }

    func testRectUnionAll() {
        let rects = [
            Rect(x: 0, y: 0, width: 10, height: 10),
            Rect(x: 50, y: 50, width: 10, height: 10),
        ]
        let u = Rect.unionAll(rects)
        XCTAssertEqual(u.x, 0); XCTAssertEqual(u.y, 0)
        XCTAssertEqual(u.right, 60); XCTAssertEqual(u.bottom, 60)
    }

    func testRectUnionAllEmpty() {
        XCTAssertEqual(Rect.unionAll([]), .zero)
    }

    // MARK: - Rect: Conversion

    func testRectCGRectRoundTrip() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        let cg = r.cgRect
        let back = Rect(cg)
        XCTAssertEqual(back.x, 10); XCTAssertEqual(back.width, 100)
    }

    // MARK: - Rect: Edges & Corners

    func testRectEdges() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(r.left, 10); XCTAssertEqual(r.top, 20)
        XCTAssertEqual(r.right, 110); XCTAssertEqual(r.bottom, 70)
    }

    func testRectCorners() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(r.topLeft, Vec2(10, 20))
        XCTAssertEqual(r.topRight, Vec2(110, 20))
        XCTAssertEqual(r.bottomLeft, Vec2(10, 70))
        XCTAssertEqual(r.bottomRight, Vec2(110, 70))
        XCTAssertEqual(r.topCenter, Vec2(60, 20))
        XCTAssertEqual(r.bottomCenter, Vec2(60, 70))
        XCTAssertEqual(r.centerLeft, Vec2(10, 45))
        XCTAssertEqual(r.centerRight, Vec2(110, 45))
        XCTAssertEqual(r.center, Vec2(60, 45))
    }

    func testRectMidXY() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(r.midX, 60); XCTAssertEqual(r.midY, 45)
    }

    // MARK: - Rect: Size

    func testRectSize() {
        let r = Rect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertEqual(r.size, Size(200, 100))
        XCTAssertEqual(r.shortestSide, 100)
        XCTAssertEqual(r.longestSide, 200)
    }

    func testRectIsEmpty() {
        XCTAssertTrue(Rect(x: 0, y: 0, width: 0, height: 100).isEmpty)
        XCTAssertTrue(Rect(x: 0, y: 0, width: 100, height: 0).isEmpty)
        XCTAssertTrue(Rect(x: 0, y: 0, width: -1, height: 100).isEmpty)
        XCTAssertFalse(Rect(x: 0, y: 0, width: 1, height: 1).isEmpty)
    }

    // MARK: - Rect: Operations

    func testRectInsetUniform() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100).inset(by: 10)
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 10)
        XCTAssertEqual(r.width, 80); XCTAssertEqual(r.height, 80)
    }

    func testRectInsetAsymmetric() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100).inset(left: 10, top: 20, right: 30, bottom: 40)
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 60); XCTAssertEqual(r.height, 40)
    }

    func testRectOutset() {
        let r = Rect(x: 10, y: 10, width: 80, height: 80).outset(by: 10)
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.width, 100)
    }

    func testRectOffset() {
        let r = Rect(x: 0, y: 0, width: 50, height: 50).offset(by: Vec2(10, 20))
        XCTAssertEqual(r.x, 10); XCTAssertEqual(r.y, 20)
        XCTAssertEqual(r.width, 50)
    }

    func testRectScaledFromCenter() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100).scaled(by: 0.5)
        XCTAssertEqual(r.width, 50, accuracy: 1e-5)
        XCTAssertEqual(r.center.x, 50, accuracy: 1e-5)
    }

    func testRectScaledFromAnchor() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100).scaled(by: 2, around: Vec2(0, 0))
        XCTAssertEqual(r.x, 0); XCTAssertEqual(r.width, 200)
    }

    // MARK: - Rect: Queries

    func testRectContains() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(r.contains(Vec2(50, 50)))
        XCTAssertTrue(r.contains(Vec2(0, 0)))
        XCTAssertTrue(r.contains(Vec2(100, 100)))
        XCTAssertFalse(r.contains(Vec2(-1, 50)))
        XCTAssertFalse(r.contains(Vec2(101, 50)))
    }

    func testRectClamp() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(r.clamp(Vec2(50, 50)), Vec2(50, 50))
        XCTAssertEqual(r.clamp(Vec2(-10, 150)), Vec2(0, 100))
    }

    func testRectIntersects() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(a.intersects(Rect(x: 50, y: 50, width: 100, height: 100)))
        XCTAssertFalse(a.intersects(Rect(x: 200, y: 200, width: 10, height: 10)))
    }

    func testRectIntersection() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 50, width: 100, height: 100)
        let i = a.intersection(b)
        XCTAssertEqual(i.x, 50); XCTAssertEqual(i.y, 50)
        XCTAssertEqual(i.width, 50); XCTAssertEqual(i.height, 50)
    }

    func testRectIntersectionNoOverlap() {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        let b = Rect(x: 50, y: 50, width: 10, height: 10)
        let i = a.intersection(b)
        XCTAssertTrue(i.isEmpty)
    }

    func testRectUnion() {
        let a = Rect(x: 0, y: 0, width: 50, height: 50)
        let b = Rect(x: 30, y: 30, width: 50, height: 50)
        let u = a.union(b)
        XCTAssertEqual(u.x, 0); XCTAssertEqual(u.y, 0)
        XCTAssertEqual(u.width, 80); XCTAssertEqual(u.height, 80)
    }

    // MARK: - Rect: Coordinate Mapping

    func testRectNormalize() {
        let r = Rect(x: 100, y: 200, width: 400, height: 300)
        let n = r.normalize(Vec2(300, 350))
        XCTAssertEqual(n.x, 0.5, accuracy: 1e-10)
        XCTAssertEqual(n.y, 0.5, accuracy: 1e-10)
    }

    func testRectNormalizeZeroSize() {
        let r = Rect(x: 0, y: 0, width: 0, height: 100)
        let n = r.normalize(Vec2(50, 50))
        XCTAssertEqual(n.x, 0) // zero width → 0
        XCTAssertEqual(n.y, 0.5, accuracy: 1e-10)
    }

    func testRectDenormalize() {
        let r = Rect(x: 100, y: 200, width: 400, height: 300)
        let d = r.denormalize(Vec2(0.5, 0.5))
        XCTAssertEqual(d.x, 300, accuracy: 1e-10)
        XCTAssertEqual(d.y, 350, accuracy: 1e-10)
    }

    func testRectPointAtAlignment() {
        let r = Rect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(r.point(at: .center), Vec2(50, 50))
        XCTAssertEqual(r.point(at: .topLeft), Vec2(0, 0))
        XCTAssertEqual(r.point(at: .bottomRight), Vec2(100, 100))
    }

    func testRectLerp() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 100, y: 100, width: 200, height: 200)
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.x, 50); XCTAssertEqual(mid.y, 50)
        XCTAssertEqual(mid.width, 150); XCTAssertEqual(mid.height, 150)
    }

    // MARK: - Size

    func testSizeZero() {
        XCTAssertEqual(Size.zero.width, 0)
        XCTAssertEqual(Size.zero.height, 0)
    }

    func testSizeSquare() {
        let s = Size(square: 50)
        XCTAssertEqual(s.width, 50); XCTAssertEqual(s.height, 50)
    }

    func testSizeProperties() {
        let s = Size(100, 50)
        XCTAssertEqual(s.shortestSide, 50)
        XCTAssertEqual(s.longestSide, 100)
        XCTAssertEqual(s.area, 5000)
        XCTAssertEqual(s.aspectRatio, 2)
    }

    func testSizeAspectRatioZeroHeight() {
        XCTAssertEqual(Size(100, 0).aspectRatio, 0)
    }

    func testSizeIsEmpty() {
        XCTAssertTrue(Size(0, 100).isEmpty)
        XCTAssertTrue(Size(100, 0).isEmpty)
        XCTAssertTrue(Size(-1, 100).isEmpty)
        XCTAssertFalse(Size(1, 1).isEmpty)
    }

    func testSizeScaledUniform() {
        let s = Size(100, 50).scaled(2)
        XCTAssertEqual(s.width, 200); XCTAssertEqual(s.height, 100)
    }

    func testSizeScaledNonUniform() {
        let s = Size(100, 50).scaled(2, 3)
        XCTAssertEqual(s.width, 200); XCTAssertEqual(s.height, 150)
    }

    func testSizeLerp() {
        let a = Size(0, 0)
        let b = Size(100, 200)
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.width, 50); XCTAssertEqual(mid.height, 100)
    }

    func testSizeToVec2() {
        let v = Size(100, 50).toVec2()
        XCTAssertEqual(v.x, 100); XCTAssertEqual(v.y, 50)
    }

    func testSizeCGRoundTrip() {
        let s = Size(100, 50)
        let back = Size(s.cgSize)
        XCTAssertEqual(back.width, 100); XCTAssertEqual(back.height, 50)
    }

    // MARK: - Alignment

    func testAlignmentConstants() {
        XCTAssertEqual(Alignment.center.x, 0); XCTAssertEqual(Alignment.center.y, 0)
        XCTAssertEqual(Alignment.topLeft.x, -1); XCTAssertEqual(Alignment.topLeft.y, -1)
        XCTAssertEqual(Alignment.bottomRight.x, 1); XCTAssertEqual(Alignment.bottomRight.y, 1)
        XCTAssertEqual(Alignment.left.x, -1); XCTAssertEqual(Alignment.left.y, 0)
        XCTAssertEqual(Alignment.right.x, 1); XCTAssertEqual(Alignment.right.y, 0)
        XCTAssertEqual(Alignment.top.x, 0); XCTAssertEqual(Alignment.top.y, -1)
        XCTAssertEqual(Alignment.bottom.x, 0); XCTAssertEqual(Alignment.bottom.y, 1)
    }

    func testAlignmentIsCenter() {
        XCTAssertTrue(Alignment.center.isCenter)
        XCTAssertFalse(Alignment.topLeft.isCenter)
        XCTAssertFalse(Alignment.left.isCenter)
    }

    func testAlignmentFromVec2() {
        let a = Alignment(Vec2(0.5, -0.5))
        XCTAssertEqual(a.x, 0.5); XCTAssertEqual(a.y, -0.5)
    }

    func testAlignmentLerp() {
        let a = Alignment.topLeft
        let b = Alignment.bottomRight
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.x, 0, accuracy: 1e-10)
        XCTAssertEqual(mid.y, 0, accuracy: 1e-10)
    }

    func testAlignmentLerpEdges() {
        let a = Alignment.topLeft
        let b = Alignment.bottomRight
        let start = a.lerp(to: b, t: 0)
        let end = a.lerp(to: b, t: 1)
        XCTAssertEqual(start.x, -1); XCTAssertEqual(start.y, -1)
        XCTAssertEqual(end.x, 1); XCTAssertEqual(end.y, 1)
    }

    // MARK: - Padding

    func testPaddingZero() {
        let p = Padding.zero
        XCTAssertEqual(p.top, 0); XCTAssertEqual(p.bottom, 0)
        XCTAssertEqual(p.leading, 0); XCTAssertEqual(p.trailing, 0)
    }

    func testPaddingAll() {
        let p = Padding(all: 10)
        XCTAssertEqual(p.horizontal, 20); XCTAssertEqual(p.vertical, 20)
    }

    func testPaddingSymmetric() {
        let p = Padding(horizontal: 10, vertical: 20)
        XCTAssertEqual(p.leading, 10); XCTAssertEqual(p.trailing, 10)
        XCTAssertEqual(p.top, 20); XCTAssertEqual(p.bottom, 20)
    }

    func testPaddingAsymmetric() {
        let p = Padding(top: 10, bottom: 20, leading: 5, trailing: 15)
        XCTAssertEqual(p.horizontal, 20)
        XCTAssertEqual(p.vertical, 30)
    }

    // MARK: - Frame

    func testFrameDefaults() {
        let f = Frame()
        if case .hug = f.width {} else { XCTFail("default width should be hug") }
        if case .hug = f.height {} else { XCTFail("default height should be hug") }
    }

    func testFrameFixed() {
        let f = Frame.fixed(100, 50)
        if case .fix(let w) = f.width { XCTAssertEqual(w, 100) } else { XCTFail() }
        if case .fix(let h) = f.height { XCTAssertEqual(h, 50) } else { XCTFail() }
    }

    func testFrameSquare() {
        let f = Frame.square(75)
        if case .fix(let w) = f.width { XCTAssertEqual(w, 75) } else { XCTFail() }
        if case .fix(let h) = f.height { XCTAssertEqual(h, 75) } else { XCTFail() }
    }

    func testFrameFill() {
        let f = Frame.fill
        if case .fill = f.width {} else { XCTFail("fill.width should be .fill") }
        if case .fill = f.height {} else { XCTFail("fill.height should be .fill") }
    }

    func testFrameFillWidth() {
        let f = Frame.fillWidth
        if case .fill = f.width {} else { XCTFail() }
        if case .hug = f.height {} else { XCTFail() }
    }

    func testFrameFillHeight() {
        let f = Frame.fillHeight
        if case .hug = f.width {} else { XCTFail() }
        if case .fill = f.height {} else { XCTFail() }
    }

    func testFrameWidthChain() {
        let f = Frame.fillWidth.height(.fix(48))
        if case .fill = f.width {} else { XCTFail() }
        if case .fix(let h) = f.height { XCTAssertEqual(h, 48) } else { XCTFail() }
    }

    func testFrameHeightChain() {
        let f = Frame.fillHeight.width(.fix(200))
        if case .fix(let w) = f.width { XCTAssertEqual(w, 200) } else { XCTFail() }
        if case .fill = f.height {} else { XCTFail() }
    }

    func testFrameHeightDoubleChain() {
        let f = Frame.fillWidth.height(100)
        if case .fix(let h) = f.height { XCTAssertEqual(h, 100) } else { XCTFail() }
    }

    func testFrameWidthDoubleChain() {
        let f = Frame.fillHeight.width(200)
        if case .fix(let w) = f.width { XCTAssertEqual(w, 200) } else { XCTFail() }
    }

    // MARK: - EdgeSet

    func testEdgeSetSingle() {
        XCTAssertTrue(EdgeSet.top.hasTop)
        XCTAssertFalse(EdgeSet.top.hasBottom)
        XCTAssertTrue(EdgeSet.bottom.hasBottom)
        XCTAssertTrue(EdgeSet.leading.hasLeading)
        XCTAssertTrue(EdgeSet.trailing.hasTrailing)
    }

    func testEdgeSetHorizontal() {
        let h = EdgeSet.horizontal
        XCTAssertTrue(h.hasLeading)
        XCTAssertTrue(h.hasTrailing)
        XCTAssertFalse(h.hasTop)
        XCTAssertFalse(h.hasBottom)
    }

    func testEdgeSetVertical() {
        let v = EdgeSet.vertical
        XCTAssertTrue(v.hasTop)
        XCTAssertTrue(v.hasBottom)
        XCTAssertFalse(v.hasLeading)
        XCTAssertFalse(v.hasTrailing)
    }

    func testEdgeSetAll() {
        let a = EdgeSet.all
        XCTAssertTrue(a.hasTop)
        XCTAssertTrue(a.hasBottom)
        XCTAssertTrue(a.hasLeading)
        XCTAssertTrue(a.hasTrailing)
    }

    func testEdgeSetUnion() {
        let combo: EdgeSet = [.top, .leading]
        XCTAssertTrue(combo.hasTop)
        XCTAssertTrue(combo.hasLeading)
        XCTAssertFalse(combo.hasBottom)
    }

    func testEdgeSetContains() {
        XCTAssertTrue(EdgeSet.all.contains(.top))
        XCTAssertTrue(EdgeSet.horizontal.contains(.leading))
        XCTAssertFalse(EdgeSet.horizontal.contains(.top))
    }
}
