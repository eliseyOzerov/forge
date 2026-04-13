import CoreGraphics
import Foundation

/// A closed path constructor. Given a bounding rect, produces a closed Path.
/// Shapes are composable via modifiers (which return new Shapes) and boolean ops.
public struct Shape {
    private let factory: (Rect) -> Path
    private let verticesFactory: ((Rect) -> [Point])?

    public init(_ factory: @escaping (Rect) -> Path) {
        self.factory = factory
        self.verticesFactory = nil
    }

    public init(_ factory: @escaping (Rect) -> Path, vertices: @escaping (Rect) -> [Point]) {
        self.factory = factory
        self.verticesFactory = vertices
    }

    public init(vertices: @escaping (Rect) -> [Point]) {
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

    public func resolve(in rect: Rect) -> Path {
        factory(rect)
    }

    public func resolve(in cgRect: CGRect) -> Path {
        factory(Rect(cgRect))
    }

    public func vertices(in rect: Rect) -> [Point] {
        verticesFactory?(rect) ?? Shape.extractVertices(from: resolve(in: rect))
    }

    // MARK: - Constructors

    public static func rect() -> Shape {
        Shape(vertices: { rect in
            [Point(rect.x, rect.y),
             Point(rect.right, rect.y),
             Point(rect.right, rect.bottom),
             Point(rect.x, rect.bottom)]
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
            let centered = Rect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
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

    public static func regular(sides: Int, rotation: Double = -.pi / 2) -> Shape {
        Shape(vertices: { rect in
            let center = rect.center
            let radius = rect.shortestSide / 2
            return (0..<sides).map { i in
                let angle = rotation + (2 * .pi * Double(i) / Double(sides))
                return Point(center.x + cos(angle) * radius, center.y + sin(angle) * radius)
            }
        })
    }

    public static func star(points: Int, innerRadius: Double = 0.4, rotation: Double = -.pi / 2) -> Shape {
        Shape(vertices: { rect in
            let center = rect.center
            let outerR = rect.shortestSide / 2
            let innerR = outerR * innerRadius
            let total = points * 2
            return (0..<total).map { i in
                let angle = rotation + (2 * .pi * Double(i) / Double(total))
                let r: Double = i.isMultiple(of: 2) ? outerR : innerR
                return Point(center.x + cos(angle) * r, center.y + sin(angle) * r)
            }
        })
    }

    public static func polygon(_ points: [Point]) -> Shape {
        Shape(vertices: { rect in
            points.map { Point(rect.x + $0.x * rect.width, rect.y + $0.y * rect.height) }
        })
    }

    // MARK: - Modifiers

    public func round(radii: [Double], smooth: Double = 0) -> Shape {
        Shape({ [self] rect in
            let verts = self.vertices(in: rect)
            guard verts.count >= 3 else { return self.resolve(in: rect) }
            return Shape.roundVertices(verts, radii: radii, smooth: smooth)
        })
    }

    public func round(radius: Double = 8, smooth: Double = 0) -> Shape {
        round(radii: [radius], smooth: smooth)
    }

    public func chamfer(size: Double) -> Shape {
        Shape({ [self] rect in
            let verts = self.vertices(in: rect)
            guard verts.count >= 3 else { return self.resolve(in: rect) }
            return Shape.chamferVertices(verts, size: size)
        })
    }

    public func scale(_ sx: Double, _ sy: Double? = nil) -> Shape {
        Shape({ [self] rect in
            let path = self.resolve(in: rect)
            let center = rect.center
            let ssy = sy ?? sx
            var t = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .scaledBy(x: sx, y: ssy)
                .translatedBy(x: -center.x, y: -center.y)
            return path.transformed(t)
        })
    }

    public func rotate(_ radians: Double) -> Shape {
        Shape({ [self] rect in
            let path = self.resolve(in: rect)
            let center = rect.center
            var t = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            return path.transformed(t)
        })
    }

    public func translate(_ dx: Double, _ dy: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect).transformed(CGAffineTransform(translationX: dx, y: dy))
        })
    }

    public func inset(_ amount: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect.inset(by: amount))
        })
    }

    public func outset(_ amount: Double) -> Shape {
        Shape({ [self] rect in
            self.resolve(in: rect.outset(by: amount))
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
    static func extractVertices(from path: Path) -> [Point] {
        var vertices: [Point] = []
        var current = CGPoint.zero

        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                current = element.pointee.points[0]
                vertices.append(Point(current))
            case .addLineToPoint:
                current = element.pointee.points[0]
                vertices.append(Point(current))
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

        if let first = vertices.first, let last = vertices.last,
           abs(first.x - last.x) < 0.5 && abs(first.y - last.y) < 0.5,
           vertices.count > 1 {
            vertices.removeLast()
        }

        return vertices
    }

    static func roundVertices(_ vertices: [Point], radii: [Double], smooth: Double) -> Path {
        let n = vertices.count
        var path = Path()

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

            let toPrev = prev - curr
            let toNext = next - curr
            let prevLen = toPrev.length
            let nextLen = toNext.length

            guard prevLen > 0, nextLen > 0 else {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            if radius <= 0 {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            let d = toPrev.dot(toNext) / (prevLen * nextLen)
            let halfAngle = acos(min(1, max(-1, d))) / 2

            guard halfAngle > 0.001 else {
                if i == 0 { path.move(to: curr) } else { path.line(to: curr) }
                continue
            }

            let cross = toPrev.cross(toNext)
            let concave = isClockwise ? cross > 0 : cross < 0

            let baseOffset = radius / tan(halfAngle)
            let maxOffset = min(prevLen, nextLen) * 0.45
            let offset = min(baseOffset, maxOffset)
            let effectiveRadius = offset * tan(halfAngle)

            let prevDir = toPrev / prevLen
            let nextDir = toNext / nextLen
            let tangentA = curr + prevDir * offset
            let tangentB = curr + nextDir * offset

            if i == 0 { path.move(to: tangentA) } else { path.line(to: tangentA) }

            if smooth <= 0 {
                let bisector = prevDir + nextDir
                let bisectorLen = bisector.length
                if bisectorLen > 0 {
                    let bisectorNorm = bisector / bisectorLen
                    let centerDist = effectiveRadius / sin(halfAngle)
                    let sign: Double = concave ? -1 : 1
                    let center = curr + bisectorNorm * centerDist * sign
                    let startAngle = atan2(tangentA.y - center.y, tangentA.x - center.x)
                    let endAngle = atan2(tangentB.y - center.y, tangentB.x - center.x)
                    path.arc(center: center, radius: effectiveRadius, startAngle: startAngle, endAngle: endAngle, clockwise: !concave)
                }
            } else {
                let k = 0.552 + smooth * 0.25
                let cpA = tangentA.lerp(to: curr, t: k)
                let cpB = tangentB.lerp(to: curr, t: k)
                path.curve(to: tangentB, control1: cpA, control2: cpB)
            }
        }

        path.close()
        return path
    }

    static func chamferVertices(_ vertices: [Point], size: Double) -> Path {
        let n = vertices.count
        var path = Path()

        for i in 0..<n {
            let prev = vertices[(i - 1 + n) % n]
            let curr = vertices[i]
            let next = vertices[(i + 1) % n]

            let toPrev = prev - curr
            let toNext = next - curr
            let prevLen = toPrev.length
            let nextLen = toNext.length

            guard prevLen > 0, nextLen > 0 else { continue }

            let offset = min(size, min(prevLen, nextLen) * 0.45)
            let tangentA = curr + (toPrev / prevLen) * offset
            let tangentB = curr + (toNext / nextLen) * offset

            if i == 0 { path.move(to: tangentA) } else { path.line(to: tangentA) }
            path.line(to: tangentB)
        }

        path.close()
        return path
    }
}
