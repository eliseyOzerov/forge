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

// MARK: - Color

public struct Color: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public func withAlpha(_ alpha: Double) -> Color {
        Color(red, green, blue, alpha)
    }

    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public func lerp(to other: Color, t: Double) -> Color {
        Color(red + (other.red - red) * t, green + (other.green - green) * t,
              blue + (other.blue - blue) * t, alpha + (other.alpha - alpha) * t)
    }

    public static func hex(_ hex: UInt32, alpha: Double = 1) -> Color {
        Color(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }

    public static let black = Color(0, 0, 0)
    public static let white = Color(1, 1, 1)
    public static let clear = Color(0, 0, 0, 0)
    public static let red = Color(1, 0, 0)
    public static let green = Color(0, 1, 0)
    public static let blue = Color(0, 0, 1)

    #if canImport(UIKit)
    public var platformColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    public init(platform: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        platform.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(Double(r), Double(g), Double(b), Double(a))
    }
    #endif
}

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

#if canImport(UIKit)
import UIKit

/// A renderable layer in a Surface. Each layer owns its rendering
/// instructions and knows how to paint itself into a CGContext.
public protocol Layer {
    func render(in ctx: CGContext, path: CGPath, bounds: CGRect)
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

    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        let resolved = shape.resolve(in: bounds).cgPath
        ctx.saveGState()
        if paint.opacity < 1 { ctx.setAlpha(paint.opacity) }
        if paint.blendMode != .normal { ctx.setBlendMode(paint.blendMode.cgBlendMode) }

        switch paint.fill {
        case .color(let color):
            ctx.addPath(resolved)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
        case .gradient(let gradient):
            ctx.addPath(resolved)
            ctx.clip()
            GradientRenderer.draw(gradient, in: bounds, ctx: ctx)
        case .image(let image, let fit):
            ctx.addPath(resolved)
            ctx.clip()
            ImageRenderer.draw(image, fit: fit, in: bounds, ctx: ctx)
        case .shader:
            break
        }

        ctx.restoreGState()
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

    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: offset.x, height: offset.y), blur: blur, color: color.cgColor)
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// MARK: - Stroke Layer

public struct StrokeLayer: Layer {
    public let stroke: Stroke
    public let paint: Paint

    public init(_ stroke: Stroke, _ paint: Paint) {
        self.stroke = stroke; self.paint = paint
    }

    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        var expandedPath = path
        if let dash = stroke.dash {
            expandedPath = expandedPath.copy(dashingWithPhase: dash.phase, lengths: dash.pattern.map { CGFloat($0) })
        }
        expandedPath = expandedPath.copy(strokingWithWidth: stroke.width, lineCap: stroke.cap.cgLineCap, lineJoin: stroke.join.cgLineJoin, miterLimit: stroke.miterLimit)

        let shapeLayer = ShapeLayer(Shape({ _ in Path(cgPath: expandedPath) }), paint)
        shapeLayer.render(in: ctx, path: expandedPath, bounds: bounds)
    }
}

// MARK: - Transform Layers

public struct ClipLayer: Layer {
    public let shape: Shape
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.addPath(shape.resolve(in: bounds).cgPath)
        ctx.clip()
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.restoreGState()
    }
}

public struct ScaleLayer: Layer {
    public let sx: Double, sy: Double
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.scaleBy(x: sx, y: sy)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.restoreGState()
    }
}

public struct TranslateLayer: Layer {
    public let dx: Double, dy: Double
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: dx, y: dy)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.restoreGState()
    }
}

public struct RotateLayer: Layer {
    public let radians: Double
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: radians)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.restoreGState()
    }
}

public struct AffineTransformLayer: Layer {
    public let transform: Transform2D
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.concatenate(transform.cgAffineTransform)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.restoreGState()
    }
}

public struct FadeLayer: Layer {
    public let opacity: Double
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.setAlpha(opacity)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}

public struct BlendLayer: Layer {
    public let mode: BlendMode
    public let children: [any Layer]
    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.setBlendMode(mode.cgBlendMode)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}

/// An isolated composited sub-surface.
public struct ComposeLayer: Layer {
    public let children: [any Layer]

    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for child in children { child.render(in: ctx, path: path, bounds: bounds) }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}

/// Custom rendering escape hatch.
public struct CustomLayer: Layer {
    public let draw: (CGContext, CGPath, CGRect) -> Void

    public func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        draw(ctx, path, bounds)
    }
}

// MARK: - Rendering Helpers

enum GradientRenderer {
    static func draw(_ gradient: Gradient, in bounds: CGRect, ctx: CGContext) {
        switch gradient {
        case .linear(let g):
            let colors = g.stops.map(\.color.cgColor) as CFArray
            let locations: [CGFloat] = g.stops.map { CGFloat($0.location) }
            guard let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            let start = CGPoint(x: bounds.minX + g.start.x * bounds.width, y: bounds.minY + g.start.y * bounds.height)
            let end = CGPoint(x: bounds.minX + g.end.x * bounds.width, y: bounds.minY + g.end.y * bounds.height)
            ctx.drawLinearGradient(cg, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .radial(let g):
            let colors = g.stops.map(\.color.cgColor) as CFArray
            let locations: [CGFloat] = g.stops.map { CGFloat($0.location) }
            guard let cg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            let center = CGPoint(x: bounds.minX + g.center.x * bounds.width, y: bounds.minY + g.center.y * bounds.height)
            let radius = g.radius * min(bounds.width, bounds.height)
            ctx.drawRadialGradient(cg, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .angular:
            break // TODO
        }
    }
}

enum ImageRenderer {
    static func draw(_ image: ImageSource, fit: ContentFit, in bounds: CGRect, ctx: CGContext) {
        guard let cgImage = image.platformImage.cgImage else { return }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let dest = fittedRect(imageSize: imageSize, in: bounds, fit: fit)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.minY + bounds.maxY)
        ctx.scaleBy(x: 1, y: -1)
        let flipped = CGRect(x: dest.minX, y: bounds.height - dest.maxY + bounds.minY, width: dest.width, height: dest.height)
        ctx.draw(cgImage, in: flipped)
        ctx.restoreGState()
    }

    static func fittedRect(imageSize: CGSize, in rect: CGRect, fit: ContentFit) -> CGRect {
        let scaleX = rect.width / imageSize.width, scaleY = rect.height / imageSize.height
        let scale: Double
        switch fit {
        case .cover: scale = max(scaleX, scaleY)
        case .contain: scale = min(scaleX, scaleY)
        case .fill: return rect
        case .scaleDown: scale = min(1, min(scaleX, scaleY))
        case .none: scale = 1
        }
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}

#endif

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

    // MARK: - Static factories

    public static func color(_ color: Color) -> Surface { Surface().color(color) }
    public static func gradient(_ gradient: Gradient) -> Surface { Surface().gradient(gradient) }
    public static func border(_ color: Color, width: Double = 1) -> Surface { Surface().border(color, width: width) }
    public static func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) -> Surface { Surface().shadow(color: color, offset: offset, blur: blur) }

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
