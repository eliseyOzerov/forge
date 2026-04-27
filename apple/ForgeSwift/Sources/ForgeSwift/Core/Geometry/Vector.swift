import CoreGraphics
import Foundation

// MARK: - Double + Clamp

public extension Double {
    /// Clamp to optional bounds. `nil` means unbounded on that side.
    func clamped(min: Double? = nil, max: Double? = nil) -> Double {
        var v = self
        if let min { v = Swift.max(v, min) }
        if let max { v = Swift.min(v, max) }
        return v
    }
    
    /// The returned value will be at least [other]
    func min(_ other: Double? = nil) -> Double { if let other { Swift.max(self, other) } else { self } }
    /// The returned value will be at most [other]
    func max(_ other: Double? = nil) -> Double { if let other { Swift.min(self, other) } else { self } }
}

// MARK: - Vector Protocol

/// A fixed-dimension numeric vector. All generic linear algebra
/// operations live here — dot, length, normalize, lerp, project, etc.
/// Concrete types (Vec2, Vec3, Vec4) add named accessors and
/// dimension-specific operations.
public protocol Vector: Equatable, Hashable, Sendable, Lerpable {
    var components: [Double] { get }
    init(components: [Double])
}

public extension Vector {
    var count: Int { components.count }

    // MARK: - Length

    var lengthSquared: Double {
        components.reduce(0) { $0 + $1 * $1 }
    }

    var length: Double { sqrt(lengthSquared) }

    var normalized: Self {
        let len = length
        guard len > 0 else { return self }
        return self / len
    }

    func withLength(_ newLength: Double) -> Self {
        normalized * newLength
    }

    // MARK: - Products

    func dot(_ other: Self) -> Double {
        zip(components, other.components).reduce(0) { $0 + $1.0 * $1.1 }
    }

    // MARK: - Distance

    func distance(to other: Self) -> Double {
        (self - other).length
    }

    func distanceSquared(to other: Self) -> Double {
        (self - other).lengthSquared
    }

    func manhattanDistance(to other: Self) -> Double {
        zip(components, other.components).reduce(0) { $0 + abs($1.0 - $1.1) }
    }

    // MARK: - Projection & Reflection

    func projected(onto other: Self) -> Self {
        let d = other.lengthSquared
        guard d > 0 else { return Self(components: [Double](repeating: 0, count: count)) }
        return other * (dot(other) / d)
    }

    func reflected(across normal: Self) -> Self {
        self - normal * (2 * dot(normal))
    }

    // MARK: - Interpolation

    func lerp(to other: Self, t: Double) -> Self {
        Self(components: zip(components, other.components).map { $0 + ($1 - $0) * t })
    }

    // MARK: - Clamping

    func clamped(min: Self, max: Self) -> Self {
        Self(components: zip(zip(components, min.components), max.components).map {
            Swift.min(Swift.max($0.0, $0.1), $1)
        })
    }

    func componentMin(_ other: Self) -> Self {
        Self(components: zip(components, other.components).map { Swift.min($0, $1) })
    }

    func componentMax(_ other: Self) -> Self {
        Self(components: zip(components, other.components).map { Swift.max($0, $1) })
    }

    // MARK: - Arithmetic

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(components: zip(lhs.components, rhs.components).map(+))
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(components: zip(lhs.components, rhs.components).map(-))
    }

    static prefix func - (v: Self) -> Self {
        Self(components: v.components.map { -$0 })
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(components: lhs.components.map { $0 * rhs })
    }

    static func * (lhs: Double, rhs: Self) -> Self {
        Self(components: rhs.components.map { $0 * lhs })
    }

    static func / (lhs: Self, rhs: Double) -> Self {
        Self(components: lhs.components.map { $0 / rhs })
    }

    // MARK: - Component-wise

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(components: zip(lhs.components, rhs.components).map(*))
    }
}

// MARK: - Vec2

/// 2D vector with cross product, perpendicular, angle, and rotation operations.
public struct Vec2: Vector {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(components: [Double]) {
        self.x = components.count > 0 ? components[0] : 0
        self.y = components.count > 1 ? components[1] : 0
    }

    public var components: [Double] { [x, y] }

    public static let zero = Vec2(0, 0)
    public static let one = Vec2(1, 1)
    public static let unitX = Vec2(1, 0)
    public static let unitY = Vec2(0, 1)

    // MARK: - 2D-specific

    /// 2D scalar cross product (z-component of 3D cross).
    public func cross(_ other: Vec2) -> Double {
        x * other.y - y * other.x
    }

    /// Perpendicular vector (90° counter-clockwise).
    public var perpendicular: Vec2 { Vec2(-y, x) }

    /// Angle from positive x-axis.
    public var angle: Double { atan2(y, x) }

    /// Signed angle from this vector to another.
    public func angle(to other: Vec2) -> Double {
        atan2(cross(other), dot(other))
    }

    /// Rotate by radians around origin.
    public func rotated(by radians: Double) -> Vec2 {
        let c = cos(radians)
        let s = sin(radians)
        return Vec2(x * c - y * s, x * s + y * c)
    }

    /// Rotate by radians around a center point.
    public func rotated(by radians: Double, around center: Vec2) -> Vec2 {
        let translated = self - center
        return translated.rotated(by: radians) + center
    }

    /// Create from angle and optional length.
    public static func fromAngle(_ radians: Double, length: Double = 1) -> Vec2 {
        Vec2(cos(radians) * length, sin(radians) * length)
    }

    /// Midpoint between two points.
    public static func midpoint(_ a: Vec2, _ b: Vec2) -> Vec2 {
        Vec2((a.x + b.x) / 2, (a.y + b.y) / 2)
    }

    // MARK: - Conversion

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    public var cgSize: CGSize { CGSize(width: x, height: y) }

    public init(_ cgPoint: CGPoint) { self.x = cgPoint.x; self.y = cgPoint.y }
    public init(_ cgSize: CGSize) { self.x = cgSize.width; self.y = cgSize.height }
}

/// Semantic alias — a Vec2 used as a position.
public typealias Point = Vec2

extension Point {
    public static func on(_ axis: Axis, main: Double, cross: Double) -> Point {
        Point(
            axis.isHorizontal ? main : cross,
            axis.isVertical ? main : cross
        )
    }
    
    public var flipped: Point { Point(y, x) }
    
    public static func &(lhs: Vec2, rhs: Size) -> Rect {
        Rect(x: lhs.x, y: lhs.y, width: rhs.width, height: rhs.height)
    }
}

// MARK: - Vec3

/// 3D vector with cross product and xy projection.
public struct Vec3: Vector {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(components: [Double]) {
        self.x = components.count > 0 ? components[0] : 0
        self.y = components.count > 1 ? components[1] : 0
        self.z = components.count > 2 ? components[2] : 0
    }

    public var components: [Double] { [x, y, z] }

    public static let zero = Vec3(0, 0, 0)
    public static let one = Vec3(1, 1, 1)
    public static let unitX = Vec3(1, 0, 0)
    public static let unitY = Vec3(0, 1, 0)
    public static let unitZ = Vec3(0, 0, 1)

    // MARK: - 3D-specific

    /// 3D cross product.
    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    /// XY projection.
    public var xy: Vec2 { Vec2(x, y) }
}

// MARK: - Vec4

/// 4D vector with xyz and xy projections.
public struct Vec4: Vector {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public init(components: [Double]) {
        self.x = components.count > 0 ? components[0] : 0
        self.y = components.count > 1 ? components[1] : 0
        self.z = components.count > 2 ? components[2] : 0
        self.w = components.count > 3 ? components[3] : 0
    }

    public var components: [Double] { [x, y, z, w] }

    public static let zero = Vec4(0, 0, 0, 0)
    public static let one = Vec4(1, 1, 1, 1)

    /// XYZ projection.
    public var xyz: Vec3 { Vec3(x, y, z) }
    /// XY projection.
    public var xy: Vec2 { Vec2(x, y) }
}
