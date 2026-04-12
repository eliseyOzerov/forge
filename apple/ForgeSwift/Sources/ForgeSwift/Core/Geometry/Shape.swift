import CoreGraphics
import Foundation

/// A closed path constructor. Given a bounding rect, produces a closed Path.
/// Shapes are composable via modifiers (which return new Shapes) and boolean ops.
public struct Shape {
    private let factory: (CGRect) -> Path
    private let verticesFactory: ((CGRect) -> [CGPoint])?

    public init(_ factory: @escaping (CGRect) -> Path) {
        self.factory = factory
        self.verticesFactory = nil
    }

    /// Custom path with known vertices (for shapes where the path is
    /// more complex than just connecting vertices — arcs, curves, etc.).
    public init(_ factory: @escaping (CGRect) -> Path, vertices: @escaping (CGRect) -> [CGPoint]) {
        self.factory = factory
        self.verticesFactory = vertices
    }

    /// Create a shape defined by its vertices. The path is derived by
    /// connecting the vertices and closing. Modifiers like round/chamfer
    /// get exact vertices without heuristic extraction.
    public init(vertices: @escaping (CGRect) -> [CGPoint]) {
        self.verticesFactory = vertices
        self.factory = { rect in
            let pts = vertices(rect)
            var p = Path()
            for (i, pt) in pts.enumerated() {
                if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
            }
            p.close()
            return p
        }
    }

    public func resolve(in rect: CGRect) -> Path {
        factory(rect)
    }

    public func vertices(in rect: CGRect) -> [CGPoint] {
        verticesFactory?(rect) ?? Shape.extractVertices(from: resolve(in: rect))
    }

    // MARK: - Constructors

    public static func rect() -> Shape {
        Shape(vertices: { rect in
            [rect.origin,
             CGPoint(x: rect.maxX, y: rect.minY),
             CGPoint(x: rect.maxX, y: rect.maxY),
             CGPoint(x: rect.minX, y: rect.maxY)]
        })
    }

    public static func roundedRect(radius: Double) -> Shape {
        Shape({ rect in
            var p = Path()
            p.addRoundedRect(rect, cornerWidth: radius, cornerHeight: radius)
            return p
        })
    }

    public static func ellipse() -> Shape {
        Shape({ rect in
            var p = Path()
            p.addEllipse(in: rect)
            return p
        })
    }

    public static func circle() -> Shape {
        Shape({ rect in
            let side = min(rect.width, rect.height)
            let centered = CGRect(
                x: rect.midX - side / 2,
                y: rect.midY - side / 2,
                width: side,
                height: side
            )
            var p = Path()
            p.addEllipse(in: centered)
            return p
        })
    }

    public static func capsule() -> Shape {
        Shape({ rect in
            let radius = min(rect.width, rect.height) / 2
            var p = Path()
            p.addRoundedRect(rect, cornerWidth: radius, cornerHeight: radius)
            return p
        })
    }

    /// Regular N-sided polygon centered in rect.
    public static func regular(sides: Int, rotation: Double = -.pi / 2) -> Shape {
        Shape(vertices: { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            return (0..<sides).map { i in
                let angle = rotation + (2 * .pi * Double(i) / Double(sides))
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }
        })
    }

    /// Star with N outer points. innerRadius is 0-1 relative to outer radius.
    public static func star(points: Int, innerRadius: Double = 0.4, rotation: Double = -.pi / 2) -> Shape {
        Shape(vertices: { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerR = min(rect.width, rect.height) / 2
            let innerR = outerR * innerRadius
            let total = points * 2
            return (0..<total).map { i in
                let angle = rotation + (2 * .pi * Double(i) / Double(total))
                let r: Double = i.isMultiple(of: 2) ? outerR : innerR
                return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            }
        })
    }

    /// Closed polygon from relative points (0-1 within rect).
    public static func polygon(_ points: [Vec2]) -> Shape {
        Shape(vertices: { rect in
            points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        })
    }

    // MARK: - Modifiers

    /// Round corners with configurable radius, cycling radii, and smooth (squircle) factor.
    ///
    /// - `radii`: radius values cycled per vertex (e.g. [8] for uniform, [8, 0, 8, 0] for alternating)
    /// - `smooth`: 0 = circular arc, 1 = cubic bezier squircle (iOS continuous corners)
    public func round(radii: [Double], smooth: Double = 0) -> Shape {
        Shape({ [self] rect in
            let verts = self.vertices(in: rect)
            guard verts.count >= 3 else { return self.resolve(in: rect) }
            return Shape.roundVertices(verts, radii: radii, smooth: smooth)
        })
    }

    /// Convenience: single radius for all corners.
    public func round(radius: Double = 8, smooth: Double = 0) -> Shape {
        round(radii: [radius], smooth: smooth)
    }

    /// Chamfer (flat cut) corners by size.
    public func chamfer(size: Double) -> Shape {
        Shape({ [self] rect in
            let verts = self.vertices(in: rect)
            guard verts.count >= 3 else { return self.resolve(in: rect) }
            return Shape.chamferVertices(verts, size: size)
        })
    }

    /// Scale around rect center.
    public func scale(_ sx: Double, _ sy: Double? = nil) -> Shape {
        Shape({ [self] rect in
            let path = self.resolve(in: rect)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let ssy = sy ?? sx
            var t = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .scaledBy(x: sx, y: ssy)
                .translatedBy(x: -center.x, y: -center.y)
            return path.transformed(t)
        })
    }

    /// Rotate around rect center.
    public func rotate(_ radians: Double) -> Shape {
        Shape({ [self] rect in
            let path = self.resolve(in: rect)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var t = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            return path.transformed(t)
        })
    }

    /// Translate the shape.
    public func translate(_ dx: Double, _ dy: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect).transformed(CGAffineTransform(translationX: dx, y: dy))
        })
    }

    /// Inset (shrink) the bounding rect before resolving.
    public func inset(_ amount: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect.insetBy(dx: amount, dy: amount))
        })
    }

    /// Outset (grow) the bounding rect before resolving.
    public func outset(_ amount: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect.insetBy(dx: -amount, dy: -amount))
        })
    }

    // MARK: - Boolean Ops

    @available(iOS 16.0, macOS 13.0, *)
    public func union(_ other: Shape) -> Shape {
        Shape({ [self] rect in self.resolve(in: rect).union(other.resolve(in: rect)) })
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func intersect(_ other: Shape) -> Shape {
        Shape({ [self] rect in self.resolve(in: rect).intersection(other.resolve(in: rect)) })
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func subtract(_ other: Shape) -> Shape {
        Shape({ [self] rect in self.resolve(in: rect).subtracting(other.resolve(in: rect)) })
    }

    @available(iOS 16.0, macOS 13.0, *)
    public func xor(_ other: Shape) -> Shape {
        Shape({ [self] rect in self.resolve(in: rect).symmetricDifference(other.resolve(in: rect)) })
    }
}

// MARK: - Vertex Rounding

extension Shape {
    /// Extract vertices from a path by detecting sharp angle changes via path element iteration.
    static func extractVertices(from path: Path) -> [CGPoint] {
        var vertices: [CGPoint] = []
        var current = CGPoint.zero

        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                current = element.pointee.points[0]
                vertices.append(current)
            case .addLineToPoint:
                current = element.pointee.points[0]
                vertices.append(current)
            case .addQuadCurveToPoint:
                current = element.pointee.points[1]
            case .addCurveToPoint:
                current = element.pointee.points[2]
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        // Remove last if it's the same as first (close)
        if let first = vertices.first, let last = vertices.last,
           abs(first.x - last.x) < 0.5 && abs(first.y - last.y) < 0.5,
           vertices.count > 1 {
            vertices.removeLast()
        }

        return vertices
    }

    /// Build a rounded path from vertices with concavity-aware arcs or squircle beziers.
    static func roundVertices(_ vertices: [CGPoint], radii: [Double], smooth: Double) -> Path {
        let n = vertices.count
        var path = Path()

        // Winding direction via shoelace
        var signedArea: Double = 0
        for i in 0..<n {
            let curr = vertices[i]
            let next = vertices[(i + 1) % n]
            signedArea += (next.x - curr.x) * (next.y + curr.y)
        }
        let isClockwise = signedArea < 0

        for i in 0..<n {
            let prev = vertices[(i - 1 + n) % n]
            let curr = vertices[i]
            let next = vertices[(i + 1) % n]
            let radius = radii[i % radii.count]

            let toPrev = CGPoint(x: prev.x - curr.x, y: prev.y - curr.y)
            let toNext = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let prevLen = hypot(toPrev.x, toPrev.y)
            let nextLen = hypot(toNext.x, toNext.y)

            guard prevLen > 0, nextLen > 0 else {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            if radius <= 0 {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            let dot = (toPrev.x * toNext.x + toPrev.y * toNext.y) / (prevLen * nextLen)
            let halfAngle = acos(min(1, max(-1, dot))) / 2

            guard halfAngle > 0.001 else {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            let cross = toPrev.x * toNext.y - toPrev.y * toNext.x
            let concave = isClockwise ? cross > 0 : cross < 0

            var baseOffset = radius / tan(halfAngle)
            let maxOffset = min(prevLen, nextLen) * 0.45
            let offset = min(baseOffset, maxOffset)
            let effectiveRadius = offset * tan(halfAngle)

            let prevDir = CGPoint(x: toPrev.x / prevLen, y: toPrev.y / prevLen)
            let nextDir = CGPoint(x: toNext.x / nextLen, y: toNext.y / nextLen)
            let tangentA = CGPoint(x: curr.x + prevDir.x * offset, y: curr.y + prevDir.y * offset)
            let tangentB = CGPoint(x: curr.x + nextDir.x * offset, y: curr.y + nextDir.y * offset)

            if i == 0 { path.move(to: tangentA) } else { path.line(to: tangentA) }

            if smooth <= 0 {
                // Circular arc
                let bisector = CGPoint(x: prevDir.x + nextDir.x, y: prevDir.y + nextDir.y)
                let bisectorLen = hypot(bisector.x, bisector.y)
                if bisectorLen > 0 {
                    let bisectorNorm = CGPoint(x: bisector.x / bisectorLen, y: bisector.y / bisectorLen)
                    let centerDist = effectiveRadius / sin(halfAngle)
                    let sign: Double = concave ? -1 : 1
                    let center = CGPoint(
                        x: curr.x + bisectorNorm.x * centerDist * sign,
                        y: curr.y + bisectorNorm.y * centerDist * sign
                    )
                    let startAngle = atan2(tangentA.y - center.y, tangentA.x - center.x)
                    let endAngle = atan2(tangentB.y - center.y, tangentB.x - center.x)
                    path.arc(center: center, radius: effectiveRadius, startAngle: startAngle, endAngle: endAngle, clockwise: !concave)
                }
            } else {
                // Squircle via cubic bezier
                let k = 0.552 + smooth * 0.25
                let cpA = CGPoint(x: tangentA.x + (curr.x - tangentA.x) * k, y: tangentA.y + (curr.y - tangentA.y) * k)
                let cpB = CGPoint(x: tangentB.x + (curr.x - tangentB.x) * k, y: tangentB.y + (curr.y - tangentB.y) * k)
                path.curve(to: tangentB, control1: cpA, control2: cpB)
            }
        }

        path.close()
        return path
    }

    /// Build a chamfered path (flat cut corners).
    static func chamferVertices(_ vertices: [CGPoint], size: Double) -> Path {
        let n = vertices.count
        var path = Path()

        for i in 0..<n {
            let prev = vertices[(i - 1 + n) % n]
            let curr = vertices[i]
            let next = vertices[(i + 1) % n]

            let toPrev = CGPoint(x: prev.x - curr.x, y: prev.y - curr.y)
            let toNext = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let prevLen = hypot(toPrev.x, toPrev.y)
            let nextLen = hypot(toNext.x, toNext.y)

            guard prevLen > 0, nextLen > 0 else { continue }

            let offset = min(size, min(prevLen, nextLen) * 0.45)
            let prevDir = CGPoint(x: toPrev.x / prevLen, y: toPrev.y / prevLen)
            let nextDir = CGPoint(x: toNext.x / nextLen, y: toNext.y / nextLen)
            let tangentA = CGPoint(x: curr.x + prevDir.x * offset, y: curr.y + prevDir.y * offset)
            let tangentB = CGPoint(x: curr.x + nextDir.x * offset, y: curr.y + nextDir.y * offset)

            if i == 0 { path.move(to: tangentA) } else { path.line(to: tangentA) }
            path.line(to: tangentB)
        }

        path.close()
        return path
    }
}
