import CoreGraphics

/// A styled surface: an optional base shape and a builder that records
/// rendering instructions. The instructions are materialized into layers
/// via `build(in:)` once the actual bounds are known at layout time.
///
/// ```swift
/// Surface(.roundedRect(radius: 12)) {
///     $0.color(.white)
///       .shadow(color: .black, blur: 8)
///       .border(.gray)
///       .fade(0.5)
///       .shape(.star(points: 5), .color(.white))
/// }
/// ```
public struct Surface {
    public var shape: Shape?
    public var instructions: [Instruction]

    public init(_ shape: Shape? = nil, build: (SurfaceBuilder) -> SurfaceBuilder) {
        self.shape = shape
        let builder = SurfaceBuilder()
        _ = build(builder)
        self.instructions = builder.instructions
    }

    public init(_ shape: Shape? = nil, instructions: [Instruction] = []) {
        self.shape = shape
        self.instructions = instructions
    }

    nonisolated(unsafe) public static let empty = Surface(instructions: [])

    /// Materialize layers from instructions given actual bounds.
    /// The base shape is resolved from the rect, and fill instructions
    /// use it as their default shape.
    public func build(in rect: CGRect) -> [any Layer] {
        let baseShape = shape ?? .rect()
        var layers: [any Layer] = []

        for instruction in instructions {
            instruction.materialize(baseShape: baseShape, rect: rect, into: &layers)
        }
        return layers
    }
}

// MARK: - Instruction

/// A recorded rendering instruction. Materialized into layers at build time
/// when the bounds and base shape are known.
public enum Instruction {
    case fill(Fill)
    case shape(Shape, Paint)
    case stroke(Stroke, Paint)
    case shadow(color: Color, offset: Vec2, blur: CGFloat)

    // Transforms consume prior instructions
    case clip(Shape)
    case scale(CGFloat, CGFloat)
    case translate(CGFloat, CGFloat)
    case rotate(CGFloat)
    case transform(Transform2D)
    case fade(CGFloat)
    case blend(BlendMode)

    case filter(Filter)
    case backdrop(Filter)

    case compose([Instruction])

    func materialize(baseShape: Shape, rect: CGRect, into layers: inout [any Layer]) {
        switch self {
        case .fill(let fill):
            layers.append(ShapeLayer(baseShape, Paint(fill)))

        case .shape(let shape, let paint):
            layers.append(ShapeLayer(shape, paint))

        case .stroke(let stroke, let paint):
            layers.append(StrokeLayer(stroke, paint))

        case .shadow(let color, let offset, let blur):
            layers.append(ShadowLayer(color: color, offset: offset, blur: blur))

        case .clip(let clipShape):
            wrapPrior(&layers) { children in
                ClipLayer(shape: clipShape, children: children)
            }

        case .scale(let sx, let sy):
            wrapPrior(&layers) { children in
                ScaleLayer(sx: sx, sy: sy, children: children)
            }

        case .translate(let dx, let dy):
            wrapPrior(&layers) { children in
                TranslateLayer(dx: dx, dy: dy, children: children)
            }

        case .rotate(let radians):
            wrapPrior(&layers) { children in
                RotateLayer(radians: radians, children: children)
            }

        case .transform(let t):
            wrapPrior(&layers) { children in
                AffineTransformLayer(transform: t, children: children)
            }

        case .fade(let alpha):
            wrapPrior(&layers) { children in
                FadeLayer(opacity: alpha, children: children)
            }

        case .blend(let mode):
            wrapPrior(&layers) { children in
                BlendLayer(mode: mode, children: children)
            }

        case .filter, .backdrop:
            break // TODO

        case .compose(let innerInstructions):
            var innerLayers: [any Layer] = []
            for instr in innerInstructions {
                instr.materialize(baseShape: baseShape, rect: rect, into: &innerLayers)
            }
            layers.append(ComposeLayer(children: innerLayers))
        }
    }

    private func wrapPrior(_ layers: inout [any Layer], _ make: ([any Layer]) -> any Layer) {
        let prior = layers
        layers = [make(prior)]
    }
}

// MARK: - Builder

/// Fluent builder that records instructions. No layers are created
/// until `Surface.build(in:)` is called with actual bounds.
public class SurfaceBuilder {
    public private(set) var instructions: [Instruction] = []

    // MARK: - Fill

    @discardableResult
    public func color(_ color: Color) -> SurfaceBuilder {
        instructions.append(.fill(.color(color))); return self
    }

    @discardableResult
    public func gradient(_ gradient: Gradient) -> SurfaceBuilder {
        instructions.append(.fill(.gradient(gradient))); return self
    }

    @discardableResult
    public func image(_ image: ImageSource, fit: ContentFit = .cover) -> SurfaceBuilder {
        instructions.append(.fill(.image(image, fit: fit))); return self
    }

    // MARK: - Shape

    @discardableResult
    public func shape(_ shape: Shape, _ paint: Paint) -> SurfaceBuilder {
        instructions.append(.shape(shape, paint)); return self
    }

    // MARK: - Stroke

    @discardableResult
    public func stroke(_ stroke: Stroke, _ paint: Paint) -> SurfaceBuilder {
        instructions.append(.stroke(stroke, paint)); return self
    }

    @discardableResult
    public func border(_ color: Color, width: CGFloat = 1) -> SurfaceBuilder {
        stroke(Stroke(width: width), .color(color))
    }

    // MARK: - Shadow

    @discardableResult
    public func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: CGFloat = 8) -> SurfaceBuilder {
        instructions.append(.shadow(color: color, offset: offset, blur: blur)); return self
    }

    // MARK: - Transforms

    @discardableResult
    public func clip(_ shape: Shape) -> SurfaceBuilder {
        instructions.append(.clip(shape)); return self
    }

    @discardableResult
    public func scale(_ sx: CGFloat, _ sy: CGFloat? = nil) -> SurfaceBuilder {
        instructions.append(.scale(sx, sy ?? sx)); return self
    }

    @discardableResult
    public func translate(_ dx: CGFloat, _ dy: CGFloat) -> SurfaceBuilder {
        instructions.append(.translate(dx, dy)); return self
    }

    @discardableResult
    public func rotate(_ radians: CGFloat) -> SurfaceBuilder {
        instructions.append(.rotate(radians)); return self
    }

    @discardableResult
    public func transform(_ t: Transform2D) -> SurfaceBuilder {
        instructions.append(.transform(t)); return self
    }

    @discardableResult
    public func fade(_ alpha: CGFloat) -> SurfaceBuilder {
        instructions.append(.fade(alpha)); return self
    }

    @discardableResult
    public func blend(_ mode: BlendMode) -> SurfaceBuilder {
        instructions.append(.blend(mode)); return self
    }

    @discardableResult
    public func filter(_ filter: Filter) -> SurfaceBuilder {
        instructions.append(.filter(filter)); return self
    }

    @discardableResult
    public func blur(_ radius: CGFloat) -> SurfaceBuilder {
        instructions.append(.backdrop(.gaussianBlur(radius: radius))); return self
    }

    // MARK: - Compose

    @discardableResult
    public func compose(_ build: (SurfaceBuilder) -> SurfaceBuilder) -> SurfaceBuilder {
        let inner = SurfaceBuilder()
        _ = build(inner)
        instructions.append(.compose(inner.instructions))
        return self
    }
}

// MARK: - SurfaceRenderer

#if canImport(UIKit)
import UIKit

public struct SurfaceRenderer {
    public let surface: Surface
    public let bounds: CGRect

    public init(surface: Surface, bounds: CGRect) {
        self.surface = surface
        self.bounds = bounds
    }

    public func render(in ctx: CGContext) {
        let layers = surface.build(in: bounds)
        let basePath = (surface.shape ?? .rect()).resolve(in: bounds).cgPath
        for layer in layers {
            layer.render(in: ctx, path: basePath, bounds: bounds)
        }
    }
}

#endif
