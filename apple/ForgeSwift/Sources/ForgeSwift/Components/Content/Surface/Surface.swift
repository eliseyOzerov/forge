import CoreGraphics

/// A styled surface. Records rendering operations via fluent methods.
/// Layers are materialized by `build(shape:)` at render time when the
/// actual shape is known.
///
/// ```swift
/// let card = Surface()
///     .color(.white)
///     .shadow(color: .black, blur: 8)
///     .border(.gray)
///
/// // Render:
/// let renderer = SurfaceRenderer(surface: card, shape: .roundedRect(radius: 12), bounds: rect)
/// renderer.render(in: ctx)
/// ```
public final class Surface {
    private var operations: [(Shape) -> [any Layer]] = []

    public init() {}

    public init(_ build: (Surface) -> Surface) {
        _ = build(self)
    }

    nonisolated(unsafe) public static let empty = Surface()

    /// Materialize layers for a given shape.
    public func build(shape: Shape) -> [any Layer] {
        var layers: [any Layer] = []
        for op in operations {
            layers.append(contentsOf: op(shape))
        }
        return layers
    }

    // MARK: - Fill (uses base shape)

    @discardableResult
    public func color(_ color: Color) -> Surface {
        operations.append { shape in [ShapeLayer(shape, .color(color))] }; return self
    }

    @discardableResult
    public func gradient(_ gradient: Gradient) -> Surface {
        operations.append { shape in [ShapeLayer(shape, .gradient(gradient))] }; return self
    }

    @discardableResult
    public func image(_ image: ImageSource, fit: ContentFit = .cover) -> Surface {
        operations.append { shape in [ShapeLayer(shape, Paint(.image(image, fit: fit)))] }; return self
    }

    // MARK: - Shape (draw additional shape)

    @discardableResult
    public func shape(_ shape: @escaping (Shape) -> Shape, _ paint: Paint) -> Surface {
        operations.append { baseShape in [ShapeLayer(shape(baseShape), paint)] }; return self
    }

    // MARK: - Stroke

    @discardableResult
    public func stroke(_ stroke: Stroke, _ paint: Paint) -> Surface {
        operations.append { _ in [StrokeLayer(stroke, paint)] }; return self
    }

    @discardableResult
    public func border(_ color: Color, width: Double = 1) -> Surface {
        stroke(Stroke(width: width), .color(color))
    }

    // MARK: - Shadow

    @discardableResult
    public func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) -> Surface {
        operations.append { _ in [ShadowLayer(color: color, offset: offset, blur: blur)] }; return self
    }

    // MARK: - Transforms (consume all prior operations)

    @discardableResult
    public func clip(_ clipShape: Shape) -> Surface {
        wrapPrior { ClipLayer(shape: clipShape, children: $0) }
    }

    @discardableResult
    public func scale(_ sx: Double, _ sy: Double? = nil) -> Surface {
        let ssy = sy ?? sx
        return wrapPrior { ScaleLayer(sx: sx, sy: ssy, children: $0) }
    }

    @discardableResult
    public func translate(_ dx: Double, _ dy: Double) -> Surface {
        wrapPrior { TranslateLayer(dx: dx, dy: dy, children: $0) }
    }

    @discardableResult
    public func rotate(_ radians: Double) -> Surface {
        wrapPrior { RotateLayer(radians: radians, children: $0) }
    }

    @discardableResult
    public func transform(_ t: Transform2D) -> Surface {
        wrapPrior { AffineTransformLayer(transform: t, children: $0) }
    }

    @discardableResult
    public func fade(_ alpha: Double) -> Surface {
        wrapPrior { FadeLayer(opacity: alpha, children: $0) }
    }

    @discardableResult
    public func blend(_ mode: BlendMode) -> Surface {
        wrapPrior { BlendLayer(mode: mode, children: $0) }
    }

    @discardableResult
    public func filter(_ filter: Filter) -> Surface {
        return self // TODO
    }

    @discardableResult
    public func blur(_ radius: Double) -> Surface {
        return self // TODO: backdrop
    }

    // MARK: - Compose (isolated sub-surface)

    @discardableResult
    public func compose(_ build: (Surface) -> Surface) -> Surface {
        let inner = Surface()
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
    private func wrapPrior(_ wrap: @escaping ([any Layer]) -> any Layer) -> Surface {
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
