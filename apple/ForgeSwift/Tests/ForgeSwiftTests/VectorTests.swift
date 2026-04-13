import XCTest
@testable import ForgeSwift

final class VectorTests: XCTestCase {

    // MARK: - Vec2

    func testVec2Arithmetic() {
        let a = Vec2(3, 4)
        let b = Vec2(1, 2)
        XCTAssertEqual(a + b, Vec2(4, 6))
        XCTAssertEqual(a - b, Vec2(2, 2))
        XCTAssertEqual(a * 2, Vec2(6, 8))
        XCTAssertEqual(a / 2, Vec2(1.5, 2))
        XCTAssertEqual(-a, Vec2(-3, -4))
    }

    func testVec2Length() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v.length, 5, accuracy: 1e-10)
        XCTAssertEqual(v.lengthSquared, 25, accuracy: 1e-10)
    }

    func testVec2Normalized() {
        let v = Vec2(3, 4).normalized
        XCTAssertEqual(v.length, 1, accuracy: 1e-10)
        XCTAssertEqual(v.x, 0.6, accuracy: 1e-10)
        XCTAssertEqual(v.y, 0.8, accuracy: 1e-10)
    }

    func testVec2NormalizedZero() {
        let v = Vec2.zero.normalized
        XCTAssertEqual(v, .zero)
    }

    func testVec2Dot() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(a.dot(b), 0, accuracy: 1e-10)
        XCTAssertEqual(a.dot(a), 1, accuracy: 1e-10)
    }

    func testVec2Cross() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(a.cross(b), 1, accuracy: 1e-10)
        XCTAssertEqual(b.cross(a), -1, accuracy: 1e-10)
    }

    func testVec2Perpendicular() {
        let v = Vec2(1, 0)
        XCTAssertEqual(v.perpendicular, Vec2(0, 1))
    }

    func testVec2Angle() {
        XCTAssertEqual(Vec2(1, 0).angle, 0, accuracy: 1e-10)
        XCTAssertEqual(Vec2(0, 1).angle, .pi / 2, accuracy: 1e-10)
        XCTAssertEqual(Vec2(-1, 0).angle, .pi, accuracy: 1e-10)
    }

    func testVec2Rotated() {
        let v = Vec2(1, 0).rotated(by: .pi / 2)
        XCTAssertEqual(v.x, 0, accuracy: 1e-10)
        XCTAssertEqual(v.y, 1, accuracy: 1e-10)
    }

    func testVec2RotatedAround() {
        let v = Vec2(2, 0).rotated(by: .pi, around: Vec2(1, 0))
        XCTAssertEqual(v.x, 0, accuracy: 1e-10)
        XCTAssertEqual(v.y, 0, accuracy: 1e-10)
    }

    func testVec2Distance() {
        let a = Vec2(0, 0)
        let b = Vec2(3, 4)
        XCTAssertEqual(a.distance(to: b), 5, accuracy: 1e-10)
    }

    func testVec2Lerp() {
        let a = Vec2(0, 0)
        let b = Vec2(10, 20)
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid, Vec2(5, 10))
    }

    func testVec2Projection() {
        let v = Vec2(3, 4)
        let onto = Vec2(1, 0)
        let proj = v.projected(onto: onto)
        XCTAssertEqual(proj.x, 3, accuracy: 1e-10)
        XCTAssertEqual(proj.y, 0, accuracy: 1e-10)
    }

    func testVec2Reflection() {
        let v = Vec2(1, -1)
        let normal = Vec2(0, 1).normalized
        let reflected = v.reflected(across: normal)
        XCTAssertEqual(reflected.x, 1, accuracy: 1e-10)
        XCTAssertEqual(reflected.y, 1, accuracy: 1e-10)
    }

    func testVec2FromAngle() {
        let v = Vec2.fromAngle(.pi / 4, length: 1)
        XCTAssertEqual(v.x, cos(.pi / 4), accuracy: 1e-10)
        XCTAssertEqual(v.y, sin(.pi / 4), accuracy: 1e-10)
    }

    func testVec2ComponentOps() {
        let a = Vec2(3, 1)
        let b = Vec2(1, 4)
        XCTAssertEqual(a.componentMin(b), Vec2(1, 1))
        XCTAssertEqual(a.componentMax(b), Vec2(3, 4))
    }

    // MARK: - Vec3

    func testVec3Cross() {
        let x = Vec3(1, 0, 0)
        let y = Vec3(0, 1, 0)
        let z = x.cross(y)
        XCTAssertEqual(z, Vec3(0, 0, 1))
    }

    func testVec3Length() {
        let v = Vec3(1, 2, 2)
        XCTAssertEqual(v.length, 3, accuracy: 1e-10)
    }

    func testVec3Projections() {
        let v = Vec3(1, 2, 3)
        XCTAssertEqual(v.xy, Vec2(1, 2))
    }

    // MARK: - Vec4

    func testVec4Projections() {
        let v = Vec4(1, 2, 3, 4)
        XCTAssertEqual(v.xyz, Vec3(1, 2, 3))
        XCTAssertEqual(v.xy, Vec2(1, 2))
    }

    // MARK: - Generic Vector Protocol

    func testVectorManhattanDistance() {
        let a = Vec2(1, 1)
        let b = Vec2(4, 5)
        XCTAssertEqual(a.manhattanDistance(to: b), 7, accuracy: 1e-10)
    }

    func testVectorWithLength() {
        let v = Vec2(3, 4).withLength(10)
        XCTAssertEqual(v.length, 10, accuracy: 1e-10)
    }

    func testVectorClamped() {
        let v = Vec2(5, -2)
        let clamped = v.clamped(min: Vec2(0, 0), max: Vec2(3, 3))
        XCTAssertEqual(clamped, Vec2(3, 0))
    }

    func testVectorComponentMultiply() {
        let a = Vec2(2, 3)
        let b = Vec2(4, 5)
        XCTAssertEqual(a * b, Vec2(8, 15))
    }

    // MARK: - Vec2 Constants

    func testVec2Constants() {
        XCTAssertEqual(Vec2.zero, Vec2(0, 0))
        XCTAssertEqual(Vec2.one, Vec2(1, 1))
        XCTAssertEqual(Vec2.unitX, Vec2(1, 0))
        XCTAssertEqual(Vec2.unitY, Vec2(0, 1))
    }

    // MARK: - Vec2 Conversions

    func testVec2CGPointRoundTrip() {
        let v = Vec2(3.5, 7.2)
        let back = Vec2(v.cgPoint)
        XCTAssertEqual(back.x, 3.5, accuracy: 1e-10)
        XCTAssertEqual(back.y, 7.2, accuracy: 1e-10)
    }

    func testVec2CGSizeRoundTrip() {
        let v = Vec2(100, 50)
        let back = Vec2(v.cgSize)
        XCTAssertEqual(back.x, 100); XCTAssertEqual(back.y, 50)
    }

    // MARK: - Vec2 Edge Cases

    func testVec2DivisionByZero() {
        let v = Vec2(1, 1) / 0
        XCTAssertTrue(v.x.isInfinite)
        XCTAssertTrue(v.y.isInfinite)
    }

    func testVec2WithLengthZeroVector() {
        let v = Vec2.zero.withLength(10)
        XCTAssertEqual(v, .zero) // can't set length on zero vector
    }

    func testVec2DistanceSquared() {
        let a = Vec2(0, 0)
        let b = Vec2(3, 4)
        XCTAssertEqual(a.distanceSquared(to: b), 25, accuracy: 1e-10)
    }

    func testVec2Midpoint() {
        let m = Vec2.midpoint(Vec2(0, 0), Vec2(10, 20))
        XCTAssertEqual(m, Vec2(5, 10))
    }

    func testVec2AngleTo() {
        let a = Vec2(1, 0)
        let b = Vec2(0, 1)
        XCTAssertEqual(a.angle(to: b), .pi / 2, accuracy: 1e-10)
    }

    func testVec2ScalarMultiplyCommutative() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v * 2, 2 * v)
    }

    // MARK: - Vec3 Extended

    func testVec3Constants() {
        XCTAssertEqual(Vec3.zero, Vec3(0, 0, 0))
        XCTAssertEqual(Vec3.one, Vec3(1, 1, 1))
        XCTAssertEqual(Vec3.unitX, Vec3(1, 0, 0))
        XCTAssertEqual(Vec3.unitY, Vec3(0, 1, 0))
        XCTAssertEqual(Vec3.unitZ, Vec3(0, 0, 1))
    }

    func testVec3Arithmetic() {
        let a = Vec3(1, 2, 3)
        let b = Vec3(4, 5, 6)
        XCTAssertEqual(a + b, Vec3(5, 7, 9))
        XCTAssertEqual(a - b, Vec3(-3, -3, -3))
        XCTAssertEqual(a * 2, Vec3(2, 4, 6))
    }

    func testVec3Dot() {
        let a = Vec3(1, 0, 0)
        let b = Vec3(0, 1, 0)
        XCTAssertEqual(a.dot(b), 0, accuracy: 1e-10)
    }

    func testVec3Normalized() {
        let v = Vec3(0, 0, 5).normalized
        XCTAssertEqual(v.z, 1, accuracy: 1e-10)
    }

    func testVec3FromComponents() {
        let v = Vec3(components: [1, 2, 3])
        XCTAssertEqual(v.x, 1); XCTAssertEqual(v.y, 2); XCTAssertEqual(v.z, 3)
    }

    func testVec3FromComponentsShort() {
        let v = Vec3(components: [1])
        XCTAssertEqual(v.x, 1); XCTAssertEqual(v.y, 0); XCTAssertEqual(v.z, 0)
    }

    // MARK: - Vec4 Extended

    func testVec4Constants() {
        XCTAssertEqual(Vec4.zero, Vec4(0, 0, 0, 0))
        XCTAssertEqual(Vec4.one, Vec4(1, 1, 1, 1))
    }

    func testVec4Arithmetic() {
        let a = Vec4(1, 2, 3, 4)
        let b = Vec4(5, 6, 7, 8)
        XCTAssertEqual(a + b, Vec4(6, 8, 10, 12))
    }

    func testVec4Length() {
        let v = Vec4(1, 0, 0, 0)
        XCTAssertEqual(v.length, 1, accuracy: 1e-10)
    }

    func testVec4FromComponents() {
        let v = Vec4(components: [1, 2, 3, 4])
        XCTAssertEqual(v.w, 4)
    }

    func testVec4FromComponentsShort() {
        let v = Vec4(components: [])
        XCTAssertEqual(v.x, 0); XCTAssertEqual(v.w, 0)
    }

    func testVec4Lerp() {
        let a = Vec4(0, 0, 0, 0)
        let b = Vec4(10, 20, 30, 40)
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.x, 5); XCTAssertEqual(mid.w, 20)
    }
}
