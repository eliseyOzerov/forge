import CoreGraphics
import Foundation

// MARK: - Shape Protocol

/// A closed path constructor. Given a bounding rect, produces a closed Path.
/// Concrete shapes are value types with inspectable parameters.
///
/// Equality and interpolation use existential dispatch — each conformer
/// checks the concrete type at runtime. No type-erasure wrappers needed.
public protocol Shape {
    func path(in rect: Rect) -> Path
    func vertices(in rect: Rect) -> [Point]
    func isEqual(to other: any Shape) -> Bool
    func lerp(to other: any Shape, t: Double) -> any Shape
}

public extension Shape {
    func vertices(in rect: Rect) -> [Point] {
        ShapeUtils.extractVertices(from: path(in: rect))
    }
}

public extension Shape where Self: Equatable {
    func isEqual(to other: any Shape) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

public extension Shape where Self: Equatable & Lerpable {
    func lerp(to other: any Shape, t: Double) -> any Shape {
        guard let other = other as? Self else { return t < 0.5 ? self : other }
        return self.lerp(to: other, t: t)
    }
}

// MARK: - Static factories (enables `.capsule()` dot syntax in generic contexts)

public extension Shape where Self == RectShape {
    static func rect() -> RectShape { RectShape() }
}
public extension Shape where Self == RoundedModifiedShape {
    static func roundedRect(radius: Double, smooth: Double = 0.6) -> RoundedModifiedShape {
        RoundedModifiedShape(base: RectShape(), radii: [radius], smooth: smooth)
    }
}
public extension Shape where Self == EllipseShape {
    static func ellipse() -> EllipseShape { EllipseShape() }
}
public extension Shape where Self == CircleShape {
    static func circle() -> CircleShape { CircleShape() }
}
public extension Shape where Self == CapsuleShape {
    static func capsule() -> CapsuleShape { CapsuleShape() }
}
public extension Shape where Self == RegularPolygon {
    static func regular(sides: Int, rotation: Double = -.pi / 2) -> RegularPolygon { RegularPolygon(sides: sides, rotation: rotation) }
}
public extension Shape where Self == StarShape {
    static func star(points: Int, innerRadius: Double = 0.4, rotation: Double = -.pi / 2) -> StarShape { StarShape(points: points, innerRadius: innerRadius, rotation: rotation) }
}
public extension Shape where Self == PolygonShape {
    static func polygon(_ points: [Point]) -> PolygonShape { PolygonShape(points: points) }
}

// MARK: - Concrete Shapes

public struct RectShape: Shape, Equatable, Lerpable {
    public init() {}
    public func path(in rect: Rect) -> Path {
        var p = Path(); p.addRect(rect); return p
    }
    public func vertices(in rect: Rect) -> [Point] {
        [Point(rect.x, rect.y), Point(rect.right, rect.y),
         Point(rect.right, rect.bottom), Point(rect.x, rect.bottom)]
    }
    public func lerp(to other: RectShape, t: Double) -> RectShape { self }
}

public struct EllipseShape: Shape, Equatable, Lerpable {
    public init() {}
    public func path(in rect: Rect) -> Path {
        var p = Path(); p.addEllipse(in: rect); return p
    }
    public func lerp(to other: EllipseShape, t: Double) -> EllipseShape { self }
}

public struct CircleShape: Shape, Equatable, Lerpable {
    public init() {}
    public func path(in rect: Rect) -> Path {
        let side = min(rect.width, rect.height)
        let centered = Rect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        var p = Path(); p.addEllipse(in: centered); return p
    }
    public func lerp(to other: CircleShape, t: Double) -> CircleShape { self }
}

public struct CapsuleShape: Shape, Equatable, Lerpable {
    public init() {}
    public func path(in rect: Rect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        var p = Path(); p.addRoundedRect(rect, cornerWidth: radius, cornerHeight: radius); return p
    }
    public func lerp(to other: CapsuleShape, t: Double) -> CapsuleShape { self }
}

public struct RegularPolygon: Shape, Equatable, Lerpable {
    public var sides: Int
    public var rotation: Double
    public init(sides: Int, rotation: Double = -.pi / 2) {
        self.sides = sides; self.rotation = rotation
    }
    public func path(in rect: Rect) -> Path {
        let verts = vertices(in: rect)
        var p = Path()
        for (i, pt) in verts.enumerated() {
            if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
        }
        p.close(); return p
    }
    public func vertices(in rect: Rect) -> [Point] {
        let center = rect.center; let r = rect.shortestSide / 2
        return (0..<sides).map { i in
            let angle = rotation + (2 * .pi * Double(i) / Double(sides))
            return Point(center.x + cos(angle) * r, center.y + sin(angle) * r)
        }
    }
    public func lerp(to other: RegularPolygon, t: Double) -> RegularPolygon {
        RegularPolygon(sides: t < 0.5 ? sides : other.sides,
                       rotation: rotation.lerp(to: other.rotation, t: t))
    }
}

public struct StarShape: Shape, Equatable, Lerpable {
    public var points: Int
    public var innerRadius: Double
    public var rotation: Double
    public init(points: Int, innerRadius: Double = 0.4, rotation: Double = -.pi / 2) {
        self.points = points; self.innerRadius = innerRadius; self.rotation = rotation
    }
    public func path(in rect: Rect) -> Path {
        let verts = vertices(in: rect)
        var p = Path()
        for (i, pt) in verts.enumerated() {
            if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
        }
        p.close(); return p
    }
    public func vertices(in rect: Rect) -> [Point] {
        let center = rect.center; let outerR = rect.shortestSide / 2
        let innerR = outerR * innerRadius; let total = points * 2
        return (0..<total).map { i in
            let angle = rotation + (2 * .pi * Double(i) / Double(total))
            let r: Double = i.isMultiple(of: 2) ? outerR : innerR
            return Point(center.x + cos(angle) * r, center.y + sin(angle) * r)
        }
    }
    public func lerp(to other: StarShape, t: Double) -> StarShape {
        StarShape(points: t < 0.5 ? points : other.points,
                  innerRadius: innerRadius.lerp(to: other.innerRadius, t: t),
                  rotation: rotation.lerp(to: other.rotation, t: t))
    }
}

public struct PolygonShape: Shape, Equatable, Lerpable {
    public var points: [Point]
    public init(points: [Point]) { self.points = points }
    public func path(in rect: Rect) -> Path {
        let mapped = points.map { Point(rect.x + $0.x * rect.width, rect.y + $0.y * rect.height) }
        var p = Path()
        for (i, pt) in mapped.enumerated() {
            if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
        }
        p.close(); return p
    }
    public func vertices(in rect: Rect) -> [Point] {
        points.map { Point(rect.x + $0.x * rect.width, rect.y + $0.y * rect.height) }
    }
    public func lerp(to other: PolygonShape, t: Double) -> PolygonShape {
        let maxCount = max(points.count, other.points.count)
        var result: [Point] = []
        for i in 0..<maxCount {
            let a = points[min(i, points.count - 1)]
            let b = other.points[min(i, other.points.count - 1)]
            result.append(a.lerp(to: b, t: t))
        }
        return PolygonShape(points: result)
    }
}

// MARK: - Modifier Shapes

public struct ScaledShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var sx: Double
    public var sy: Double
    public init(base: any Shape, sx: Double, sy: Double) {
        self.base = base; self.sx = sx; self.sy = sy
    }
    public func path(in rect: Rect) -> Path {
        let p = base.path(in: rect); let center = rect.center
        let t = CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -center.x, y: -center.y)
        return p.transformed(t)
    }
    public func lerp(to other: ScaledShape, t: Double) -> ScaledShape {
        ScaledShape(base: base.lerp(to: other.base, t: t),
                    sx: sx.lerp(to: other.sx, t: t),
                    sy: sy.lerp(to: other.sy, t: t))
    }
    public static func ==(lhs: ScaledShape, rhs: ScaledShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.sx == rhs.sx && lhs.sy == rhs.sy
    }
}

public struct RotatedShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var radians: Double
    public init(base: any Shape, radians: Double) {
        self.base = base; self.radians = radians
    }
    public func path(in rect: Rect) -> Path {
        let p = base.path(in: rect); let center = rect.center
        let t = CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: radians)
            .translatedBy(x: -center.x, y: -center.y)
        return p.transformed(t)
    }
    public func lerp(to other: RotatedShape, t: Double) -> RotatedShape {
        RotatedShape(base: base.lerp(to: other.base, t: t),
                     radians: radians.lerp(to: other.radians, t: t))
    }
    public static func ==(lhs: RotatedShape, rhs: RotatedShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.radians == rhs.radians
    }
}

public struct TranslatedShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var dx: Double
    public var dy: Double
    public init(base: any Shape, dx: Double, dy: Double) {
        self.base = base; self.dx = dx; self.dy = dy
    }
    public func path(in rect: Rect) -> Path {
        base.path(in: rect).transformed(CGAffineTransform(translationX: dx, y: dy))
    }
    public func lerp(to other: TranslatedShape, t: Double) -> TranslatedShape {
        TranslatedShape(base: base.lerp(to: other.base, t: t),
                        dx: dx.lerp(to: other.dx, t: t),
                        dy: dy.lerp(to: other.dy, t: t))
    }
    public static func ==(lhs: TranslatedShape, rhs: TranslatedShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.dx == rhs.dx && lhs.dy == rhs.dy
    }
}

public struct InsetShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var amount: Double
    public init(base: any Shape, amount: Double) {
        self.base = base; self.amount = amount
    }
    public func path(in rect: Rect) -> Path { base.path(in: rect.inset(by: amount)) }
    public func lerp(to other: InsetShape, t: Double) -> InsetShape {
        InsetShape(base: base.lerp(to: other.base, t: t),
                   amount: amount.lerp(to: other.amount, t: t))
    }
    public static func ==(lhs: InsetShape, rhs: InsetShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.amount == rhs.amount
    }
}

public struct RoundedModifiedShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var radii: [Double]
    public var smooth: Double
    public init(base: any Shape, radii: [Double], smooth: Double) {
        self.base = base; self.radii = radii; self.smooth = smooth
    }
    public func path(in rect: Rect) -> Path {
        let verts = base.vertices(in: rect)
        guard verts.count >= 3 else { return base.path(in: rect) }
        return ShapeUtils.roundVertices(verts, radii: radii, smooth: smooth)
    }
    public func vertices(in rect: Rect) -> [Point] { base.vertices(in: rect) }
    public func lerp(to other: RoundedModifiedShape, t: Double) -> RoundedModifiedShape {
        let maxRadii = max(radii.count, other.radii.count)
        var lerpedRadii: [Double] = []
        for i in 0..<maxRadii {
            let a = radii[min(i, radii.count - 1)]
            let b = other.radii[min(i, other.radii.count - 1)]
            lerpedRadii.append(a.lerp(to: b, t: t))
        }
        return RoundedModifiedShape(base: base.lerp(to: other.base, t: t),
                                    radii: lerpedRadii,
                                    smooth: smooth.lerp(to: other.smooth, t: t))
    }
    public static func ==(lhs: RoundedModifiedShape, rhs: RoundedModifiedShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.radii == rhs.radii && lhs.smooth == rhs.smooth
    }
}

public struct ChamferedShape: Shape, Equatable, Lerpable {
    public var base: any Shape
    public var size: Double
    public init(base: any Shape, size: Double) {
        self.base = base; self.size = size
    }
    public func path(in rect: Rect) -> Path {
        let verts = base.vertices(in: rect)
        guard verts.count >= 3 else { return base.path(in: rect) }
        return ShapeUtils.chamferVertices(verts, size: size)
    }
    public func vertices(in rect: Rect) -> [Point] { base.vertices(in: rect) }
    public func lerp(to other: ChamferedShape, t: Double) -> ChamferedShape {
        ChamferedShape(base: base.lerp(to: other.base, t: t),
                       size: size.lerp(to: other.size, t: t))
    }
    public static func ==(lhs: ChamferedShape, rhs: ChamferedShape) -> Bool {
        lhs.base.isEqual(to: rhs.base) && lhs.size == rhs.size
    }
}

// MARK: - Boolean Ops

@available(iOS 16.0, macOS 13.0, *)
public struct UnionShape: Shape, Equatable, Lerpable {
    public var a: any Shape
    public var b: any Shape
    public init(a: any Shape, b: any Shape) { self.a = a; self.b = b }
    public func path(in rect: Rect) -> Path { a.path(in: rect).union(b.path(in: rect)) }
    public func lerp(to other: UnionShape, t: Double) -> UnionShape {
        UnionShape(a: a.lerp(to: other.a, t: t), b: b.lerp(to: other.b, t: t))
    }
    public static func ==(lhs: UnionShape, rhs: UnionShape) -> Bool {
        lhs.a.isEqual(to: rhs.a) && lhs.b.isEqual(to: rhs.b)
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct IntersectionShape: Shape, Equatable, Lerpable {
    public var a: any Shape
    public var b: any Shape
    public init(a: any Shape, b: any Shape) { self.a = a; self.b = b }
    public func path(in rect: Rect) -> Path { a.path(in: rect).intersection(b.path(in: rect)) }
    public func lerp(to other: IntersectionShape, t: Double) -> IntersectionShape {
        IntersectionShape(a: a.lerp(to: other.a, t: t), b: b.lerp(to: other.b, t: t))
    }
    public static func ==(lhs: IntersectionShape, rhs: IntersectionShape) -> Bool {
        lhs.a.isEqual(to: rhs.a) && lhs.b.isEqual(to: rhs.b)
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SubtractionShape: Shape, Equatable, Lerpable {
    public var a: any Shape
    public var b: any Shape
    public init(a: any Shape, b: any Shape) { self.a = a; self.b = b }
    public func path(in rect: Rect) -> Path { a.path(in: rect).subtracting(b.path(in: rect)) }
    public func lerp(to other: SubtractionShape, t: Double) -> SubtractionShape {
        SubtractionShape(a: a.lerp(to: other.a, t: t), b: b.lerp(to: other.b, t: t))
    }
    public static func ==(lhs: SubtractionShape, rhs: SubtractionShape) -> Bool {
        lhs.a.isEqual(to: rhs.a) && lhs.b.isEqual(to: rhs.b)
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SymmetricDifferenceShape: Shape, Equatable, Lerpable {
    public var a: any Shape
    public var b: any Shape
    public init(a: any Shape, b: any Shape) { self.a = a; self.b = b }
    public func path(in rect: Rect) -> Path { a.path(in: rect).symmetricDifference(b.path(in: rect)) }
    public func lerp(to other: SymmetricDifferenceShape, t: Double) -> SymmetricDifferenceShape {
        SymmetricDifferenceShape(a: a.lerp(to: other.a, t: t), b: b.lerp(to: other.b, t: t))
    }
    public static func ==(lhs: SymmetricDifferenceShape, rhs: SymmetricDifferenceShape) -> Bool {
        lhs.a.isEqual(to: rhs.a) && lhs.b.isEqual(to: rhs.b)
    }
}

// MARK: - CustomShape (closure escape hatch)

public struct CustomShape: Shape {
    public var id: String?
    public let factory: (Rect) -> Path
    public let verticesFactory: ((Rect) -> [Point])?

    public init(id: String? = nil, _ factory: @escaping (Rect) -> Path, vertices: ((Rect) -> [Point])? = nil) {
        self.id = id; self.factory = factory; self.verticesFactory = vertices
    }

    public func path(in rect: Rect) -> Path { factory(rect) }
    public func vertices(in rect: Rect) -> [Point] {
        verticesFactory?(rect) ?? ShapeUtils.extractVertices(from: path(in: rect))
    }

    public func isEqual(to other: any Shape) -> Bool {
        guard let other = other as? CustomShape,
              let lid = id, let rid = other.id else { return false }
        return lid == rid
    }
    public func lerp(to other: any Shape, t: Double) -> any Shape {
        t < 0.5 ? self : other
    }
}

// MARK: - Shape Modifiers (extension on protocol)

public extension Shape {
    func scaled(_ sx: Double, _ sy: Double? = nil) -> any Shape {
        ScaledShape(base: self, sx: sx, sy: sy ?? sx)
    }
    func rotated(_ radians: Double) -> any Shape {
        RotatedShape(base: self, radians: radians)
    }
    func translated(_ dx: Double, _ dy: Double) -> any Shape {
        TranslatedShape(base: self, dx: dx, dy: dy)
    }
    func inset(_ amount: Double) -> any Shape {
        InsetShape(base: self, amount: amount)
    }
    func outset(_ amount: Double) -> any Shape {
        InsetShape(base: self, amount: -amount)
    }
    func round(radii: [Double], smooth: Double = 0.6) -> any Shape {
        RoundedModifiedShape(base: self, radii: radii, smooth: smooth)
    }
    func round(radius: Double = 8, smooth: Double = 0.6) -> any Shape {
        round(radii: [radius], smooth: smooth)
    }
    func chamfer(size: Double) -> any Shape {
        ChamferedShape(base: self, size: size)
    }
}

@available(iOS 16.0, macOS 13.0, *)
public extension Shape {
    func union(_ other: any Shape) -> any Shape {
        UnionShape(a: self, b: other)
    }
    func intersect(_ other: any Shape) -> any Shape {
        IntersectionShape(a: self, b: other)
    }
    func subtract(_ other: any Shape) -> any Shape {
        SubtractionShape(a: self, b: other)
    }
    func xor(_ other: any Shape) -> any Shape {
        SymmetricDifferenceShape(a: self, b: other)
    }
}

// MARK: - Utilities

enum ShapeUtils {
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
