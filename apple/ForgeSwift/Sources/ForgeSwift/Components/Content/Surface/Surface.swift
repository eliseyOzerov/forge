#if canImport(UIKit)
import UIKit
#endif

/// A styled surface: an optional base shape and an ordered list of
/// layers. Each transform consumes all prior layers, wrapping them.
///
/// ```swift
/// Surface(.roundedRect(radius: 12)) {
///     $0.color(.white)
///       .shadow(color: .black, blur: 8)
///       .stroke(.init(width: 1), .color(.gray))
///       .clip(.circle())
///       .gradient(.linear(colors: [.red, .blue]))
///       .fade(0.5)
///       .shape(.star(points: 5), .color(.white))
///       .compose { $0.color(.black.withAlpha(0.3)).blur(10) }
/// }
/// ```
public struct Surface {
    public var shape: Shape?
    public var layers: [any Layer]

    public init(_ shape: Shape? = nil, build: (SurfaceBuilder) -> SurfaceBuilder) {
        self.shape = shape
        let builder = SurfaceBuilder()
        _ = build(builder)
        self.layers = builder.layers
    }

    public init(_ shape: Shape? = nil, layers: [any Layer] = []) {
        self.shape = shape
        self.layers = layers
    }

    nonisolated(unsafe) public static let empty = Surface(layers: [])
}

// MARK: - Builder

/// Fluent builder for Surface. Each method appends a layer and returns
/// self. Transform methods (clip, scale, rotate, etc.) consume all
/// prior layers, wrapping them into a single TransformLayer.
public class SurfaceBuilder {
    public private(set) var layers: [any Layer] = []

    // MARK: - Fill (shortcuts for shape fill using the base shape)

    @discardableResult
    public func color(_ color: Color) -> SurfaceBuilder {
        layers.append(ShapeLayer(.rect(), .color(color))); return self
    }

    @discardableResult
    public func gradient(_ gradient: Gradient) -> SurfaceBuilder {
        layers.append(ShapeLayer(.rect(), .gradient(gradient))); return self
    }

    @discardableResult
    public func image(_ image: ImageSource, fit: ContentFit = .cover) -> SurfaceBuilder {
        layers.append(ShapeLayer(.rect(), Paint(.image(image, fit: fit)))); return self
    }

    // MARK: - Shape

    @discardableResult
    public func shape(_ shape: Shape, _ paint: Paint) -> SurfaceBuilder {
        layers.append(ShapeLayer(shape, paint)); return self
    }

    // MARK: - Stroke

    @discardableResult
    public func stroke(_ stroke: Stroke, _ paint: Paint) -> SurfaceBuilder {
        layers.append(StrokeLayer(stroke, paint)); return self
    }

    @discardableResult
    public func border(_ color: Color, width: CGFloat = 1) -> SurfaceBuilder {
        stroke(Stroke(width: width), .color(color))
    }

    // MARK: - Shadow

    @discardableResult
    public func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: CGFloat = 8) -> SurfaceBuilder {
        layers.append(ShadowLayer(color: color, offset: offset, blur: blur)); return self
    }

    // MARK: - Transforms (consume prior layers)

    @discardableResult
    public func clip(_ shape: Shape) -> SurfaceBuilder {
        wrapPrior { children in
            TransformLayer(children: children, apply: { ctx, _, bounds in
                let clipPath = shape.resolve(in: bounds)
                ctx.addPath(clipPath.cgPath)
                ctx.clip()
            }, cleanup: nil)
        }
    }

    @discardableResult
    public func scale(_ sx: CGFloat, _ sy: CGFloat? = nil) -> SurfaceBuilder {
        let ssy = sy ?? sx
        return wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.scaleBy(x: sx, y: ssy) }, cleanup: nil) }
    }

    @discardableResult
    public func translate(_ dx: CGFloat, _ dy: CGFloat) -> SurfaceBuilder {
        wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.translateBy(x: dx, y: dy) }, cleanup: nil) }
    }

    @discardableResult
    public func rotate(_ radians: CGFloat) -> SurfaceBuilder {
        wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.rotate(by: radians) }, cleanup: nil) }
    }

    @discardableResult
    public func transform(_ t: Transform2D) -> SurfaceBuilder {
        wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.concatenate(t.cgAffineTransform) }, cleanup: nil) }
    }

    @discardableResult
    public func fade(_ alpha: CGFloat) -> SurfaceBuilder {
        wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.setAlpha(alpha) }, cleanup: nil) }
    }

    @discardableResult
    public func blend(_ mode: BlendMode) -> SurfaceBuilder {
        wrapPrior { TransformLayer(children: $0, apply: { ctx, _, _ in ctx.setBlendMode(mode.cgBlendMode) }, cleanup: nil) }
    }

    @discardableResult
    public func filter(_ filter: Filter) -> SurfaceBuilder {
        // TODO: render prior to offscreen, apply CIFilter, composite
        return self
    }

    @discardableResult
    public func blur(_ radius: CGFloat) -> SurfaceBuilder {
        // TODO: backdrop blur at view level
        return self
    }

    // MARK: - Compose (isolated sub-surface)

    @discardableResult
    public func compose(_ build: (SurfaceBuilder) -> SurfaceBuilder) -> SurfaceBuilder {
        let inner = SurfaceBuilder()
        _ = build(inner)
        layers.append(ComposeLayer(children: inner.layers))
        return self
    }

    // MARK: - Custom

    @discardableResult
    public func custom(_ draw: @escaping (CGContext, CGPath, CGRect) -> Void) -> SurfaceBuilder {
        layers.append(CustomLayer(draw: draw)); return self
    }

    // MARK: - Internal

    /// Consume all prior layers into a transform layer.
    @discardableResult
    private func wrapPrior(_ makeLayer: ([any Layer]) -> any Layer) -> SurfaceBuilder {
        let prior = layers
        layers = [makeLayer(prior)]
        return self
    }
}

#if canImport(UIKit)
import UIKit

/// Renders a Surface into a CGContext.
public struct SurfaceRenderer {
    public let surface: Surface
    public let bounds: CGRect

    public init(surface: Surface, bounds: CGRect) {
        self.surface = surface
        self.bounds = bounds
    }

    public func render(in ctx: CGContext) {
        let basePath = (surface.shape ?? .rect()).resolve(in: bounds).cgPath
        for layer in surface.layers {
            layer.render(in: ctx, path: basePath, bounds: bounds)
        }
    }
}

#endif
