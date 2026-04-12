import CoreGraphics

/// A styled surface. Records rendering operations via a fluent closure.
/// Layers are materialized by `build(shape:)` at render time when the
/// actual shape is known.
///
/// ```swift
/// let card = Surface {
///     $0.color(.white)
///       .shadow(color: .black, blur: 8)
///       .border(.gray)
/// }
///
/// // Render:
/// let layers = card.build(shape: .roundedRect(radius: 12))
/// renderer.render(layers, in: ctx, bounds: rect)
/// ```
public struct Surface {
    public let operations: [(Shape) -> [any Layer]]

    public init(_ build: (SurfaceBuilder) -> SurfaceBuilder) {
        let b = SurfaceBuilder()
        _ = build(b)
        self.operations = b.operations
    }

    public init(operations: [(Shape) -> [any Layer]]) {
        self.operations = operations
    }

    nonisolated(unsafe) public static let empty = Surface(operations: [])

    /// Materialize layers for a given shape.
    public func build(shape: Shape) -> [any Layer] {
        var layers: [any Layer] = []
        for op in operations {
            let newLayers = op(shape)
            layers.append(contentsOf: newLayers)
        }
        return layers
    }
}

// MARK: - Builder

public class SurfaceBuilder {
    var operations: [(Shape) -> [any Layer]] = []

    // MARK: - Fill (uses base shape)

    @discardableResult
    public func color(_ color: Color) -> SurfaceBuilder {
        operations.append { shape in [ShapeLayer(shape, .color(color))] }; return self
    }

    @discardableResult
    public func gradient(_ gradient: Gradient) -> SurfaceBuilder {
        operations.append { shape in [ShapeLayer(shape, .gradient(gradient))] }; return self
    }

    @discardableResult
    public func image(_ image: ImageSource, fit: ContentFit = .cover) -> SurfaceBuilder {
        operations.append { shape in [ShapeLayer(shape, Paint(.image(image, fit: fit)))] }; return self
    }

    // MARK: - Shape (draw additional shape)

    @discardableResult
    public func shape(_ shape: Shape, _ paint: Paint) -> SurfaceBuilder {
        operations.append { _ in [ShapeLayer(shape, paint)] }; return self
    }

    // MARK: - Stroke

    @discardableResult
    public func stroke(_ stroke: Stroke, _ paint: Paint) -> SurfaceBuilder {
        operations.append { _ in [StrokeLayer(stroke, paint)] }; return self
    }

    @discardableResult
    public func border(_ color: Color, width: CGFloat = 1) -> SurfaceBuilder {
        stroke(Stroke(width: width), .color(color))
    }

    // MARK: - Shadow

    @discardableResult
    public func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: CGFloat = 8) -> SurfaceBuilder {
        operations.append { _ in [ShadowLayer(color: color, offset: offset, blur: blur)] }; return self
    }

    // MARK: - Transforms (consume all prior operations)

    @discardableResult
    public func clip(_ clipShape: Shape) -> SurfaceBuilder {
        wrapPrior { ClipLayer(shape: clipShape, children: $0) }
    }

    @discardableResult
    public func scale(_ sx: CGFloat, _ sy: CGFloat? = nil) -> SurfaceBuilder {
        let ssy = sy ?? sx
        return wrapPrior { ScaleLayer(sx: sx, sy: ssy, children: $0) }
    }

    @discardableResult
    public func translate(_ dx: CGFloat, _ dy: CGFloat) -> SurfaceBuilder {
        wrapPrior { TranslateLayer(dx: dx, dy: dy, children: $0) }
    }

    @discardableResult
    public func rotate(_ radians: CGFloat) -> SurfaceBuilder {
        wrapPrior { RotateLayer(radians: radians, children: $0) }
    }

    @discardableResult
    public func transform(_ t: Transform2D) -> SurfaceBuilder {
        wrapPrior { AffineTransformLayer(transform: t, children: $0) }
    }

    @discardableResult
    public func fade(_ alpha: CGFloat) -> SurfaceBuilder {
        wrapPrior { FadeLayer(opacity: alpha, children: $0) }
    }

    @discardableResult
    public func blend(_ mode: BlendMode) -> SurfaceBuilder {
        wrapPrior { BlendLayer(mode: mode, children: $0) }
    }

    @discardableResult
    public func filter(_ filter: Filter) -> SurfaceBuilder {
        return self // TODO
    }

    @discardableResult
    public func blur(_ radius: CGFloat) -> SurfaceBuilder {
        return self // TODO: backdrop
    }

    // MARK: - Compose (isolated sub-surface)

    @discardableResult
    public func compose(_ build: (SurfaceBuilder) -> SurfaceBuilder) -> SurfaceBuilder {
        let inner = SurfaceBuilder()
        _ = build(inner)
        let innerOps = inner.operations
        operations.append { shape in
            var children: [any Layer] = []
            for op in innerOps { children.append(contentsOf: op(shape)) }
            return [ComposeLayer(children: children)]
        }
        return self
    }

    // MARK: - Internal

    @discardableResult
    private func wrapPrior(_ wrap: @escaping ([any Layer]) -> any Layer) -> SurfaceBuilder {
        let prior = operations
        operations = [{ shape in
            var children: [any Layer] = []
            for op in prior { children.append(contentsOf: op(shape)) }
            return [wrap(children)]
        }]
        return self
    }
}

// MARK: - SurfaceRenderer

#if canImport(UIKit)
import UIKit

public struct SurfaceRenderer {
    public let surface: Surface
    public let shape: Shape
    public let bounds: CGRect

    public init(surface: Surface, shape: Shape, bounds: CGRect) {
        self.surface = surface
        self.shape = shape
        self.bounds = bounds
    }

    public func render(in ctx: CGContext) {
        let layers = surface.build(shape: shape)
        let basePath = shape.resolve(in: bounds).cgPath
        for layer in layers {
            layer.render(in: ctx, path: basePath, bounds: bounds)
        }
    }
}

#endif
