import CoreGraphics
import Foundation

/// An axis-aligned rectangle.
public struct Rect {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    // MARK: - Factories

    public static func fromLTRB(_ left: CGFloat, _ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat) -> Rect {
        Rect(x: left, y: top, width: right - left, height: bottom - top)
    }

    public static func fromCenter(_ center: Vec2, width: CGFloat, height: CGFloat) -> Rect {
        Rect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    public static func fromCircle(center: Vec2, radius: CGFloat) -> Rect {
        Rect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    public static func fromSize(_ size: Size) -> Rect {
        Rect(x: 0, y: 0, width: size.width, height: size.height)
    }

    public static func fromPoints(_ points: [Vec2]) -> Rect {
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func unionAll(_ rects: [Rect]) -> Rect {
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    // MARK: - Conversion

    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    public init(_ cgRect: CGRect) { self.x = cgRect.minX; self.y = cgRect.minY; self.width = cgRect.width; self.height = cgRect.height }

    // MARK: - Edges

    public var left: CGFloat { x }
    public var top: CGFloat { y }
    public var right: CGFloat { x + width }
    public var bottom: CGFloat { y + height }

    // MARK: - Corners & Centers

    public var topLeft: Vec2 { Vec2(x, y) }
    public var topRight: Vec2 { Vec2(right, y) }
    public var bottomLeft: Vec2 { Vec2(x, bottom) }
    public var bottomRight: Vec2 { Vec2(right, bottom) }
    public var topCenter: Vec2 { Vec2(midX, y) }
    public var bottomCenter: Vec2 { Vec2(midX, bottom) }
    public var centerLeft: Vec2 { Vec2(x, midY) }
    public var centerRight: Vec2 { Vec2(right, midY) }
    public var center: Vec2 { Vec2(midX, midY) }

    public var midX: CGFloat { x + width / 2 }
    public var midY: CGFloat { y + height / 2 }

    // MARK: - Size

    public var size: Size { Size(width, height) }
    public var shortestSide: CGFloat { min(width, height) }
    public var longestSide: CGFloat { max(width, height) }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    // MARK: - Operations

    public func inset(by amount: CGFloat) -> Rect {
        Rect(x: x + amount, y: y + amount, width: width - amount * 2, height: height - amount * 2)
    }

    public func inset(left: CGFloat = 0, top: CGFloat = 0, right: CGFloat = 0, bottom: CGFloat = 0) -> Rect {
        Rect(x: x + left, y: y + top, width: width - left - right, height: height - top - bottom)
    }

    public func outset(by amount: CGFloat) -> Rect {
        inset(by: -amount)
    }

    public func offset(by delta: Vec2) -> Rect {
        Rect(x: x + delta.x, y: y + delta.y, width: width, height: height)
    }

    public func scaled(by factor: CGFloat, around anchor: Vec2? = nil) -> Rect {
        let a = anchor ?? center
        return Rect(
            x: a.x + (x - a.x) * factor,
            y: a.y + (y - a.y) * factor,
            width: width * factor,
            height: height * factor
        )
    }

    // MARK: - Queries

    public func contains(_ point: Vec2) -> Bool {
        point.x >= x && point.x <= right && point.y >= y && point.y <= bottom
    }

    public func clamp(_ point: Vec2) -> Vec2 {
        Vec2(min(max(point.x, x), right), min(max(point.y, y), bottom))
    }

    public func intersects(_ other: Rect) -> Bool {
        left < other.right && right > other.left && top < other.bottom && bottom > other.top
    }

    public func intersection(_ other: Rect) -> Rect {
        .fromLTRB(max(left, other.left), max(top, other.top), min(right, other.right), min(bottom, other.bottom))
    }

    public func union(_ other: Rect) -> Rect {
        .fromLTRB(min(left, other.left), min(top, other.top), max(right, other.right), max(bottom, other.bottom))
    }

    // MARK: - Coordinate Mapping

    /// Map a point to normalized [0,1]² coordinates within this rect.
    public func normalize(_ point: Vec2) -> Vec2 {
        Vec2(width == 0 ? 0 : (point.x - x) / width, height == 0 ? 0 : (point.y - y) / height)
    }

    /// Map a [0,1]² coordinate to absolute coordinates within this rect.
    public func denormalize(_ fraction: Vec2) -> Vec2 {
        Vec2(x + fraction.x * width, y + fraction.y * height)
    }

    /// Resolve an Alignment (-1...1 on each axis) to a point inside this rect.
    public func point(at alignment: Alignment) -> Vec2 {
        let nx = (alignment.x + 1) / 2
        let ny = (alignment.y + 1) / 2
        return Vec2(x + width * nx, y + height * ny)
    }

    // MARK: - Interpolation

    public func lerp(to other: Rect, t: CGFloat) -> Rect {
        Rect(
            x: x + (other.x - x) * t,
            y: y + (other.y - y) * t,
            width: width + (other.width - width) * t,
            height: height + (other.height - height) * t
        )
    }
}

extension Rect: Equatable, Hashable, Sendable {}
