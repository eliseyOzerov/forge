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

    public mutating func move(to point: CGPoint) {
        cgPath.move(to: point)
    }

    public mutating func line(to point: CGPoint) {
        cgPath.addLine(to: point)
    }

    public mutating func curve(to point: CGPoint, control1: CGPoint, control2: CGPoint) {
        cgPath.addCurve(to: point, control1: control1, control2: control2)
    }

    public mutating func quadCurve(to point: CGPoint, control: CGPoint) {
        cgPath.addQuadCurve(to: point, control: control)
    }

    public mutating func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        cgPath.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
    }

    public mutating func arcTo(_ point: CGPoint, tangent1: CGPoint, tangent2: CGPoint, radius: CGFloat) {
        cgPath.addArc(tangent1End: tangent1, tangent2End: tangent2, radius: radius)
    }

    public mutating func close() {
        cgPath.closeSubpath()
    }

    public mutating func addRect(_ rect: CGRect) {
        cgPath.addRect(rect)
    }

    public mutating func addEllipse(in rect: CGRect) {
        cgPath.addEllipse(in: rect)
    }

    public mutating func addRoundedRect(_ rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat) {
        cgPath.addRoundedRect(in: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight)
    }

    public mutating func addPath(_ other: Path) {
        cgPath.addPath(other.cgPath)
    }

    // MARK: - Constructors

    public static func line(from: CGPoint, to: CGPoint) -> Path {
        var p = Path()
        p.move(to: from)
        p.line(to: to)
        return p
    }

    public static func polyline(_ points: [CGPoint]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() {
            p.line(to: point)
        }
        return p
    }

    public static func polygon(_ points: [CGPoint]) -> Path {
        var p = polyline(points)
        p.close()
        return p
    }

    public static func bezier(_ points: [CGPoint]) -> Path {
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

    public static func arc(in rect: CGRect, startAngle: CGFloat, sweepAngle: CGFloat) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.arc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweepAngle, clockwise: sweepAngle < 0)
        return p
    }

    public static func spiral(in rect: CGRect, turns: CGFloat = 3, startRadius: CGFloat = 0, endRadius: CGFloat? = nil, samples: Int = 200) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = endRadius ?? min(rect.width, rect.height) / 2
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let angle = turns * 2 * .pi * t
            let r = startRadius + (maxR - startRadius) * t
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { p.move(to: point) } else { p.line(to: point) }
        }
        return p
    }

    // MARK: - Derived Paths

    public func dashed(phase: CGFloat = 0, lengths: [CGFloat]) -> Path {
        Path(cgPath: cgPath.copy(dashingWithPhase: phase, lengths: lengths))
    }

    public func stroked(width: CGFloat, cap: CGLineCap = .butt, join: CGLineJoin = .miter, miterLimit: CGFloat = 10) -> Path {
        Path(cgPath: cgPath.copy(strokingWithWidth: width, lineCap: cap, lineJoin: join, miterLimit: miterLimit))
    }

    public func transformed(_ transform: CGAffineTransform) -> Path {
        var t = transform
        return Path(cgPath: cgPath.mutableCopy(using: &t)!)
    }

    // MARK: - Queries

    public var boundingBox: CGRect { cgPath.boundingBoxOfPath }
    public var isEmpty: Bool { cgPath.isEmpty }
    public var currentPoint: CGPoint { cgPath.currentPoint }

    public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding) -> Bool {
        cgPath.contains(point, using: rule)
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

    /// Total arc length of the path.
    public var length: CGFloat {
        segments.reduce(0) { $0 + $1.length }
    }

    /// Position and tangent angle at a given distance along the path.
    public func tangent(at distance: CGFloat) -> PathTangent? {
        let segs = segments
        guard !segs.isEmpty else { return nil }

        var remaining = max(0, distance)
        for seg in segs {
            if remaining <= seg.length {
                let t = seg.length > 0 ? remaining / seg.length : 0
                let point = CGPoint(
                    x: seg.start.x + (seg.end.x - seg.start.x) * t,
                    y: seg.start.y + (seg.end.y - seg.start.y) * t
                )
                let angle = atan2(seg.end.y - seg.start.y, seg.end.x - seg.start.x)
                return PathTangent(point: point, angle: angle)
            }
            remaining -= seg.length
        }

        // Past the end — return last point
        if let last = segs.last {
            let angle = atan2(last.end.y - last.start.y, last.end.x - last.start.x)
            return PathTangent(point: last.end, angle: angle)
        }
        return nil
    }

    /// Position at a given distance along the path.
    public func point(at distance: CGFloat) -> CGPoint? {
        tangent(at: distance)?.point
    }

    /// Sample the path at evenly spaced intervals.
    public func sample(count: Int) -> [PathTangent] {
        let totalLength = length
        guard totalLength > 0, count > 1 else {
            if let t = tangent(at: 0) { return [t] }
            return []
        }
        return (0..<count).compactMap { i in
            let d = totalLength * CGFloat(i) / CGFloat(count - 1)
            return tangent(at: d)
        }
    }

    /// Flatten the path into line segments for metric computation.
    private var segments: [PathSegment] {
        var result: [PathSegment] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                current = element.pointee.points[0]
                subpathStart = current
            case .addLineToPoint:
                let end = element.pointee.points[0]
                result.append(PathSegment(start: current, end: end))
                current = end
            case .addQuadCurveToPoint:
                let cp = element.pointee.points[0]
                let end = element.pointee.points[1]
                Path.flattenQuad(from: current, control: cp, to: end, into: &result)
                current = end
            case .addCurveToPoint:
                let cp1 = element.pointee.points[0]
                let cp2 = element.pointee.points[1]
                let end = element.pointee.points[2]
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

    private static func flattenQuad(from p0: CGPoint, control cp: CGPoint, to p2: CGPoint, into segments: inout [PathSegment], depth: Int = 0) {
        if depth > 8 || isFlat(p0, cp, p2) {
            segments.append(PathSegment(start: p0, end: p2))
            return
        }
        let mid01 = CGPoint(x: (p0.x + cp.x) / 2, y: (p0.y + cp.y) / 2)
        let mid12 = CGPoint(x: (cp.x + p2.x) / 2, y: (cp.y + p2.y) / 2)
        let mid = CGPoint(x: (mid01.x + mid12.x) / 2, y: (mid01.y + mid12.y) / 2)
        flattenQuad(from: p0, control: mid01, to: mid, into: &segments, depth: depth + 1)
        flattenQuad(from: mid, control: mid12, to: p2, into: &segments, depth: depth + 1)
    }

    private static func flattenCubic(from p0: CGPoint, control1 cp1: CGPoint, control2 cp2: CGPoint, to p3: CGPoint, into segments: inout [PathSegment], depth: Int = 0) {
        if depth > 8 || isFlat(p0, cp1, cp2, p3) {
            segments.append(PathSegment(start: p0, end: p3))
            return
        }
        let mid01 = CGPoint(x: (p0.x + cp1.x) / 2, y: (p0.y + cp1.y) / 2)
        let mid12 = CGPoint(x: (cp1.x + cp2.x) / 2, y: (cp1.y + cp2.y) / 2)
        let mid23 = CGPoint(x: (cp2.x + p3.x) / 2, y: (cp2.y + p3.y) / 2)
        let mid012 = CGPoint(x: (mid01.x + mid12.x) / 2, y: (mid01.y + mid12.y) / 2)
        let mid123 = CGPoint(x: (mid12.x + mid23.x) / 2, y: (mid12.y + mid23.y) / 2)
        let mid = CGPoint(x: (mid012.x + mid123.x) / 2, y: (mid012.y + mid123.y) / 2)
        flattenCubic(from: p0, control1: mid01, control2: mid012, to: mid, into: &segments, depth: depth + 1)
        flattenCubic(from: mid, control1: mid123, control2: mid23, to: p3, into: &segments, depth: depth + 1)
    }

    private static func isFlat(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Bool {
        let dx = p2.x - p0.x, dy = p2.y - p0.y
        let d = abs((p1.x - p0.x) * dy - (p1.y - p0.y) * dx)
        return d * d <= 0.25 * (dx * dx + dy * dy)
    }

    private static func isFlat(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> Bool {
        let dx = p3.x - p0.x, dy = p3.y - p0.y
        let d1 = abs((p1.x - p3.x) * dy - (p1.y - p3.y) * dx)
        let d2 = abs((p2.x - p3.x) * dy - (p2.y - p3.y) * dx)
        let dSq = (d1 + d2) * (d1 + d2)
        return dSq <= 0.25 * (dx * dx + dy * dy)
    }
}

// MARK: - Supporting Types

public struct PathTangent {
    public let point: CGPoint
    public let angle: CGFloat

    /// Unit direction vector at this point.
    public var direction: Vec2 { Vec2(cos(angle), sin(angle)) }

    /// Normal (perpendicular, 90° counter-clockwise from direction).
    public var normal: Vec2 { Vec2(-sin(angle), cos(angle)) }
}

private struct PathSegment {
    let start: CGPoint
    let end: CGPoint
    var length: CGFloat { hypot(end.x - start.x, end.y - start.y) }
}
