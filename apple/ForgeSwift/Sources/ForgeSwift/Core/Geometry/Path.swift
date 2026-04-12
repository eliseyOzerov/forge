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
}
