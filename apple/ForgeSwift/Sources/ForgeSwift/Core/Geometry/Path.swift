#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Platform-agnostic path primitive. Wraps the native path type
/// (CGPath on Apple) so calling code stays consistent across platforms.
public struct Path {
    public private(set) var cgPath: CGMutablePath

    public init() {
        cgPath = CGMutablePath()
    }

    init(cgPath: CGPath) {
        self.cgPath = cgPath.mutableCopy()!
    }

    // MARK: - Building

    public mutating func move(to point: Point) {
        cgPath.move(to: point.cgPoint)
    }

    public mutating func line(to point: Point) {
        cgPath.addLine(to: point.cgPoint)
    }

    public mutating func curve(to point: Point, control1: Point, control2: Point) {
        cgPath.addCurve(to: point.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
    }

    public mutating func quadCurve(to point: Point, control: Point) {
        cgPath.addQuadCurve(to: point.cgPoint, control: control.cgPoint)
    }

    public mutating func arc(center: Point, radius: Double, startAngle: Double, endAngle: Double, clockwise: Bool) {
        cgPath.addArc(center: center.cgPoint, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
    }

    public mutating func close() {
        cgPath.closeSubpath()
    }

    public mutating func addRect(_ rect: Rect) {
        cgPath.addRect(rect.cgRect)
    }

    public mutating func addEllipse(in rect: Rect) {
        cgPath.addEllipse(in: rect.cgRect)
    }

    public mutating func addRoundedRect(_ rect: Rect, cornerWidth: Double, cornerHeight: Double) {
        cgPath.addRoundedRect(in: rect.cgRect, cornerWidth: cornerWidth, cornerHeight: cornerHeight)
    }

    public mutating func addPath(_ other: Path) {
        cgPath.addPath(other.cgPath)
    }

    // MARK: - Constructors

    public static func line(from: Point, to: Point) -> Path {
        var p = Path()
        p.move(to: from)
        p.line(to: to)
        return p
    }

    public static func polyline(_ points: [Point]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() {
            p.line(to: point)
        }
        return p
    }

    public static func polygon(_ points: [Point]) -> Path {
        var p = polyline(points)
        p.close()
        return p
    }

    public static func bezier(_ points: [Point]) -> Path {
        var p = Path()
        guard points.count >= 4, (points.count - 1) % 3 == 0 else { return p }
        p.move(to: points[0])
        var i = 1
        while i + 2 < points.count {
            p.curve(to: points[i + 2], control1: points[i], control2: points[i + 1])
            i += 3
        }
        return p
    }

    public static func arc(in rect: Rect, startAngle: Double, sweepAngle: Double) -> Path {
        var p = Path()
        let center = rect.center
        let radius = min(rect.width, rect.height) / 2
        p.arc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweepAngle, clockwise: sweepAngle < 0)
        return p
    }

    public static func spiral(in rect: Rect, turns: Double = 3, startRadius: Double = 0, endRadius: Double? = nil, samples: Int = 200) -> Path {
        var p = Path()
        let center = rect.center
        let maxR = endRadius ?? min(rect.width, rect.height) / 2
        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let angle = turns * 2 * .pi * t
            let r = startRadius + (maxR - startRadius) * t
            let point = Point(center.x + cos(angle) * r, center.y + sin(angle) * r)
            if i == 0 { p.move(to: point) } else { p.line(to: point) }
        }
        return p
    }

    // MARK: - Derived Paths

    public func dashed(phase: Double = 0, lengths: [Double]) -> Path {
        Path(cgPath: cgPath.copy(dashingWithPhase: phase, lengths: lengths.map { CGFloat($0) }))
    }

    public func stroked(width: Double, cap: StrokeCap = .butt, join: StrokeJoin = .miter, miterLimit: Double = 10) -> Path {
        Path(cgPath: cgPath.copy(strokingWithWidth: width, lineCap: cap.cgLineCap, lineJoin: join.cgLineJoin, miterLimit: miterLimit))
    }

    public func transformed(_ transform: CGAffineTransform) -> Path {
        var t = transform
        return Path(cgPath: cgPath.mutableCopy(using: &t)!)
    }

    // MARK: - Queries

    public var boundingBox: Rect { Rect(cgPath.boundingBoxOfPath) }
    public var isEmpty: Bool { cgPath.isEmpty }
    public var currentPoint: Point { Point(cgPath.currentPoint) }

    public func contains(_ point: Point, using rule: CGPathFillRule = .winding) -> Bool {
        cgPath.contains(point.cgPoint, using: rule)
    }

    // MARK: - Boolean Ops (iOS 16+)

    @available(iOS 16.0, macOS 13.0, *)
    public func union(_ other: Path) -> Path {
        Path(cgPath: cgPath.union(other.cgPath))
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func intersection(_ other: Path) -> Path {
        Path(cgPath: cgPath.intersection(other.cgPath))
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func subtracting(_ other: Path) -> Path {
        Path(cgPath: cgPath.subtracting(other.cgPath))
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func symmetricDifference(_ other: Path) -> Path {
        Path(cgPath: cgPath.symmetricDifference(other.cgPath))
    }

    // MARK: - Path Metrics

    public var length: Double {
        segments.reduce(0) { $0 + $1.length }
    }

    public func tangent(at distance: Double) -> PathTangent? {
        let segs = segments
        guard !segs.isEmpty else { return nil }

        var remaining = max(0, distance)
        for seg in segs {
            if remaining <= seg.length {
                let t = seg.length > 0 ? remaining / seg.length : 0
                let point = Point(
                    seg.start.x + (seg.end.x - seg.start.x) * t,
                    seg.start.y + (seg.end.y - seg.start.y) * t
                )
                let angle = atan2(seg.end.y - seg.start.y, seg.end.x - seg.start.x)
                return PathTangent(point: point, angle: angle)
            }
            remaining -= seg.length
        }

        if let last = segs.last {
            let angle = atan2(last.end.y - last.start.y, last.end.x - last.start.x)
            return PathTangent(point: last.end, angle: angle)
        }
        return nil
    }

    public func point(at distance: Double) -> Point? {
        tangent(at: distance)?.point
    }

    public func sample(count: Int) -> [PathTangent] {
        let totalLength = length
        guard totalLength > 0, count > 1 else {
            if let t = tangent(at: 0) { return [t] }
            return []
        }
        return (0..<count).compactMap { i in
            let d = totalLength * Double(i) / Double(count - 1)
            return tangent(at: d)
        }
    }

    // MARK: - Segments (internal)

    private var segments: [PathSegment] {
        var result: [PathSegment] = []
        var current = Point.zero
        var subpathStart = Point.zero

        cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                current = Point(element.pointee.points[0])
                subpathStart = current
            case .addLineToPoint:
                let end = Point(element.pointee.points[0])
                result.append(PathSegment(start: current, end: end))
                current = end
            case .addQuadCurveToPoint:
                let cp = Point(element.pointee.points[0])
                let end = Point(element.pointee.points[1])
                Path.flattenQuad(from: current, control: cp, to: end, into: &result)
                current = end
            case .addCurveToPoint:
                let cp1 = Point(element.pointee.points[0])
                let cp2 = Point(element.pointee.points[1])
                let end = Point(element.pointee.points[2])
                Path.flattenCubic(from: current, control1: cp1, control2: cp2, to: end, into: &result)
                current = end
            case .closeSubpath:
                if current != subpathStart {
                    result.append(PathSegment(start: current, end: subpathStart))
                }
                current = subpathStart
            @unknown default:
                break
            }
        }
        return result
    }

    // MARK: - Curve Flattening

    private static func flattenQuad(from p0: Point, control cp: Point, to p2: Point, into segments: inout [PathSegment], depth: Int = 0) {
        if depth > 8 || isFlat(p0, cp, p2) {
            segments.append(PathSegment(start: p0, end: p2))
            return
        }
        let mid01 = Vec2.midpoint(p0, cp)
        let mid12 = Vec2.midpoint(cp, p2)
        let mid = Vec2.midpoint(mid01, mid12)
        flattenQuad(from: p0, control: mid01, to: mid, into: &segments, depth: depth + 1)
        flattenQuad(from: mid, control: mid12, to: p2, into: &segments, depth: depth + 1)
    }

    private static func flattenCubic(from p0: Point, control1 cp1: Point, control2 cp2: Point, to p3: Point, into segments: inout [PathSegment], depth: Int = 0) {
        if depth > 8 || isFlat(p0, cp1, cp2, p3) {
            segments.append(PathSegment(start: p0, end: p3))
            return
        }
        let mid01 = Vec2.midpoint(p0, cp1)
        let mid12 = Vec2.midpoint(cp1, cp2)
        let mid23 = Vec2.midpoint(cp2, p3)
        let mid012 = Vec2.midpoint(mid01, mid12)
        let mid123 = Vec2.midpoint(mid12, mid23)
        let mid = Vec2.midpoint(mid012, mid123)
        flattenCubic(from: p0, control1: mid01, control2: mid012, to: mid, into: &segments, depth: depth + 1)
        flattenCubic(from: mid, control1: mid123, control2: mid23, to: p3, into: &segments, depth: depth + 1)
    }

    private static func isFlat(_ p0: Point, _ p1: Point, _ p2: Point) -> Bool {
        let d = p2 - p0
        let det = abs((p1.x - p0.x) * d.y - (p1.y - p0.y) * d.x)
        return det * det <= 0.25 * d.lengthSquared
    }

    private static func isFlat(_ p0: Point, _ p1: Point, _ p2: Point, _ p3: Point) -> Bool {
        let d = p3 - p0
        let d1 = abs((p1.x - p3.x) * d.y - (p1.y - p3.y) * d.x)
        let d2 = abs((p2.x - p3.x) * d.y - (p2.y - p3.y) * d.x)
        let dSq = (d1 + d2) * (d1 + d2)
        return dSq <= 0.25 * d.lengthSquared
    }
}

// MARK: - Supporting Types

public struct PathTangent {
    public let point: Point
    public let angle: Double
    public var direction: Vec2 { Vec2(cos(angle), sin(angle)) }
    public var normal: Vec2 { Vec2(-sin(angle), cos(angle)) }
}

private struct PathSegment {
    let start: Point
    let end: Point
    var length: Double { (end - start).length }
}
