#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What to fill a shape with.
public enum Fill {
    case color(Color)
    case gradient(Gradient)
    case image(ImageSource, fit: ContentFit = .cover)
    case shader(Shader)
}

/// Liquid-Glass material variant. Maps to `UIGlassEffect` on iOS 26+.
///
/// - `regular`: the standard translucent glass, used for most chrome
///   (nav bars, tab bars, sheets).
/// - `prominent`: higher-opacity, more saturated — for floating
///   controls that need to pop.
/// - `clear`: most translucent, used at scroll-edges where the glass
///   should nearly disappear against the content underneath.
public enum GlassStyle: Sendable, Equatable {
    case regular, prominent, clear
}

// Color is defined in Core/View/Color.swift

// MARK: - Gradient

public enum Gradient {
    case linear(LinearGradient)
    case radial(RadialGradient)
    case angular(AngularGradient)
}

public struct GradientStop: Sendable {
    public var color: Color
    public var location: Double
    public init(_ color: Color, at location: Double) { self.color = color; self.location = location }
}

public struct LinearGradient: Sendable {
    public var stops: [GradientStop]
    public var start: Vec2
    public var end: Vec2
    public init(stops: [GradientStop], start: Vec2 = Vec2(0.5, 0), end: Vec2 = Vec2(0.5, 1)) {
        self.stops = stops; self.start = start; self.end = end
    }
    public init(colors: [Color], start: Vec2 = Vec2(0.5, 0), end: Vec2 = Vec2(0.5, 1)) {
        let n = colors.count
        self.stops = colors.enumerated().map { GradientStop($1, at: n > 1 ? Double($0) / Double(n - 1) : 0) }
        self.start = start; self.end = end
    }
}

public struct RadialGradient: Sendable {
    public var stops: [GradientStop]
    public var center: Vec2
    public var radius: Double
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), radius: Double = 0.5) {
        self.stops = stops; self.center = center; self.radius = radius
    }
}

public struct AngularGradient: Sendable {
    public var stops: [GradientStop]
    public var center: Vec2
    public var startAngle: Double
    public var endAngle: Double
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), startAngle: Double = 0, endAngle: Double = .pi * 2) {
        self.stops = stops; self.center = center; self.startAngle = startAngle; self.endAngle = endAngle
    }
}

// MARK: - ImageSource

public struct ImageSource {
    #if canImport(UIKit)
    public let platformImage: UIImage
    public init(_ platformImage: UIImage) { self.platformImage = platformImage }
    #elseif canImport(AppKit)
    public let platformImage: NSImage
    public init(_ platformImage: NSImage) { self.platformImage = platformImage }
    #endif
}

// MARK: - ContentFit

public enum ContentFit: Sendable {
    case fill, contain, cover, scaleDown, none

    /// Compute the destination rect for content of `contentSize` fitted into `bounds`.
    public func rect(for contentSize: Size, in bounds: Rect) -> Rect {
        switch self {
        case .fill:
            return bounds
        case .contain:
            let scale = min(bounds.width / contentSize.width, bounds.height / contentSize.height)
            let w = contentSize.width * scale, h = contentSize.height * scale
            return Rect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
        case .cover:
            let scale = max(bounds.width / contentSize.width, bounds.height / contentSize.height)
            let w = contentSize.width * scale, h = contentSize.height * scale
            return Rect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
        case .scaleDown:
            let scale = min(1, min(bounds.width / contentSize.width, bounds.height / contentSize.height))
            let w = contentSize.width * scale, h = contentSize.height * scale
            return Rect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
        case .none:
            return Rect(x: bounds.midX - contentSize.width / 2, y: bounds.midY - contentSize.height / 2, width: contentSize.width, height: contentSize.height)
        }
    }
}

// MARK: - Shader

public struct Shader { public init() {} }

// MARK: - Paint

public struct Paint {
    public var fill: Fill
    public var blendMode: BlendMode
    public var opacity: Double

    public init(_ fill: Fill, blendMode: BlendMode = .normal, opacity: Double = 1) {
        self.fill = fill; self.blendMode = blendMode; self.opacity = opacity
    }

    public static func color(_ color: Color) -> Paint { Paint(.color(color)) }
    public static func gradient(_ gradient: Gradient) -> Paint { Paint(.gradient(gradient)) }
}

// MARK: - BlendMode

public enum BlendMode: Sendable {
    case normal, multiply, screen, overlay
    case darken, lighten, colorDodge, colorBurn
    case softLight, hardLight, difference, exclusion
    case hue, saturation, color, luminosity
    case clear, copy
    case sourceIn, sourceOut, sourceAtop
    case destinationOver, destinationIn, destinationOut, destinationAtop
    case xor

    #if canImport(CoreGraphics)
    public var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: .normal; case .multiply: .multiply; case .screen: .screen; case .overlay: .overlay
        case .darken: .darken; case .lighten: .lighten; case .colorDodge: .colorDodge; case .colorBurn: .colorBurn
        case .softLight: .softLight; case .hardLight: .hardLight; case .difference: .difference; case .exclusion: .exclusion
        case .hue: .hue; case .saturation: .saturation; case .color: .color; case .luminosity: .luminosity
        case .clear: .clear; case .copy: .copy
        case .sourceIn: .sourceIn; case .sourceOut: .sourceOut; case .sourceAtop: .sourceAtop
        case .destinationOver: .destinationOver; case .destinationIn: .destinationIn; case .destinationOut: .destinationOut; case .destinationAtop: .destinationAtop
        case .xor: .xor
        }
    }
    #endif
}

// MARK: - Stroke

public struct Stroke: Sendable {
    public var width: Double
    public var cap: StrokeCap
    public var join: StrokeJoin
    public var alignment: Double
    public var miterLimit: Double
    public var dash: Dash?

    public init(width: Double = 1, cap: StrokeCap = .round, join: StrokeJoin = .round, alignment: Double = 0.5, miterLimit: Double = 10, dash: Dash? = nil) {
        self.width = width; self.cap = cap; self.join = join; self.alignment = alignment; self.miterLimit = miterLimit; self.dash = dash
    }
}

public enum StrokeCap: Sendable {
    case butt, round, square
    #if canImport(CoreGraphics)
    public var cgLineCap: CGLineCap { switch self { case .butt: .butt; case .round: .round; case .square: .square } }
    #endif
}

public enum StrokeJoin: Sendable {
    case miter, round, bevel
    #if canImport(CoreGraphics)
    public var cgLineJoin: CGLineJoin { switch self { case .miter: .miter; case .round: .round; case .bevel: .bevel } }
    #endif
}

public struct Dash: Sendable {
    public var pattern: [Double]
    public var phase: Double
    public init(_ pattern: [Double], phase: Double = 0) { self.pattern = pattern; self.phase = phase }
    public static func even(_ length: Double) -> Dash { Dash([length, length]) }
}

// Filter is defined in Canvas.swift

// MARK: - Transform2D

public struct Transform2D: Sendable {
    public var a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double

    public init(a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, tx: Double = 0, ty: Double = 0) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }

    public static let identity = Transform2D()

    public func concatenating(_ other: Transform2D) -> Transform2D {
        Transform2D(
            a: a * other.a + b * other.c, b: a * other.b + b * other.d,
            c: c * other.a + d * other.c, d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx, ty: tx * other.b + ty * other.d + other.ty
        )
    }

    #if canImport(CoreGraphics)
    public var cgAffineTransform: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
    public init(_ cg: CGAffineTransform) { self.a = cg.a; self.b = cg.b; self.c = cg.c; self.d = cg.d; self.tx = cg.tx; self.ty = cg.ty }
    #endif
}

public enum RotationAxis: Sendable { case x, y, z }
public enum FillRule: Sendable { case winding, evenOdd }

/// A renderable layer in a Surface. Each layer owns its rendering
/// instructions and knows how to paint itself onto a Canvas.
public protocol Layer {
    func render(on canvas: Canvas, path: Path, bounds: Rect)
}

// MARK: - Shape Layer

/// Fills a shape with a paint.
public struct ShapeLayer: Layer {
    public let shape: Shape
    public let paint: Paint

    public init(_ shape: Shape, _ paint: Paint) {
        self.shape = shape
        self.paint = paint
    }

    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        let resolved = shape.resolve(in: bounds)
        canvas.draw(resolved, with: paint)
    }
}

// MARK: - Shadow Layer

public struct ShadowLayer: Layer {
    public let color: Color
    public let offset: Vec2
    public let blur: Double

    public init(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) {
        self.color = color; self.offset = offset; self.blur = blur
    }

    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.filter(.shadow(color: color, offset: offset, blur: blur))
        canvas.draw(path, with: .color(color))
        canvas.restore()
    }
}

// MARK: - Stroke Layer

public struct StrokeLayer: Layer {
    public let stroke: Stroke
    public let paint: Paint

    public init(_ stroke: Stroke, _ paint: Paint) {
        self.stroke = stroke; self.paint = paint
    }

    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        var expanded = path
        if let dash = stroke.dash {
            expanded = expanded.dashed(phase: dash.phase, lengths: dash.pattern)
        }
        expanded = expanded.stroked(width: stroke.width, cap: stroke.cap, join: stroke.join, miterLimit: stroke.miterLimit)
        canvas.draw(expanded, with: paint)
    }
}

// MARK: - Transform Layers

public struct ClipLayer: Layer {
    public let shape: Shape
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.clip(shape.resolve(in: bounds))
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct ScaleLayer: Layer {
    public let sx: Double, sy: Double
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.translate(bounds.midX, bounds.midY)
        canvas.scale(sx, sy)
        canvas.translate(-bounds.midX, -bounds.midY)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct TranslateLayer: Layer {
    public let dx: Double, dy: Double
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.translate(dx, dy)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct RotateLayer: Layer {
    public let radians: Double
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.translate(bounds.midX, bounds.midY)
        canvas.rotate(radians)
        canvas.translate(-bounds.midX, -bounds.midY)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct AffineTransformLayer: Layer {
    public let transform: Transform2D
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.transform(transform)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct FadeLayer: Layer {
    public let opacity: Double
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.setAlpha(opacity)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

public struct BlendLayer: Layer {
    public let mode: BlendMode
    public let children: [any Layer]
    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        canvas.setBlendMode(mode)
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

/// An isolated composited sub-surface.
public struct ComposeLayer: Layer {
    public let children: [any Layer]

    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        canvas.save()
        for child in children { child.render(on: canvas, path: path, bounds: bounds) }
        canvas.restore()
    }
}

/// Custom rendering escape hatch.
public struct CustomLayer: Layer {
    public let draw: (Canvas, Path, Rect) -> Void

    public func render(on canvas: Canvas, path: Path, bounds: Rect) {
        draw(canvas, path, bounds)
    }
}

// MARK: - SurfaceRenderer

public struct SurfaceRenderer {
    public let surface: Surface
    public let shape: Shape
    public let bounds: Rect

    public init(surface: Surface, shape: Shape, bounds: Rect) {
        self.surface = surface
        self.shape = shape
        self.bounds = bounds
    }

    public func render(on canvas: Canvas) {
        let layers = surface.build(shape: shape)
        let basePath = shape.resolve(in: bounds)
        for layer in layers {
            layer.render(on: canvas, path: basePath, bounds: bounds)
        }
    }
}

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

    /// First solid fill color this Surface was configured with, if any.
    /// Recorded alongside the layer operation for consumers that need
    /// a plain `UIColor` at the UIKit boundary (nav bars, tab bars,
    /// `backgroundColor` settings) without re-deriving it from the
    /// operation closures. First-wins — subsequent `.color(...)` calls
    /// layer on top but don't overwrite this.
    public private(set) var primaryColor: Color?

    /// Liquid-Glass style, if this Surface expresses one. Set via
    /// `Surface.glass(...)` / `.glass(...)`. Consumers with UIKit
    /// integration (nav bar appearance, sheets, custom controls)
    /// can read this to configure their native glass effect; pure
    /// Canvas consumers ignore it — the effect is view-composited,
    /// not drawn.
    public private(set) var glassStyle: GlassStyle?

    public init() {}

    public init(_ build: (Surface) -> Surface) {
        _ = build(self)
    }

    nonisolated(unsafe) public static let empty = Surface()

    // MARK: - Static factories

    public static func color(_ color: Color) -> Surface { Surface().color(color) }
    public static func gradient(_ gradient: Gradient) -> Surface { Surface().gradient(gradient) }
    public static func border(_ color: Color, width: Double = 1) -> Surface { Surface().border(color, width: width) }
    public static func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) -> Surface { Surface().shadow(color: color, offset: offset, blur: blur) }
    public static func glass(_ style: GlassStyle = .regular) -> Surface { Surface().glass(style) }

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
        if primaryColor == nil { primaryColor = color }
        operations.append { shape in [ShapeLayer(shape, .color(color))] }; return self
    }

    /// Declare this Surface as a Liquid-Glass material. Does not add
    /// a drawable layer — glass is rendered by the OS via a view-level
    /// effect, not by painting to a Canvas. Consumers that render
    /// Surfaces through a UIView hierarchy pick this up via
    /// `glassStyle` and install a `UIVisualEffectView(UIGlassEffect())`
    /// as a backing layer; Canvas-only renderers ignore it.
    @discardableResult
    public func glass(_ style: GlassStyle = .regular) -> Surface {
        self.glassStyle = style
        return self
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
