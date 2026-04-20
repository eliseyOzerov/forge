#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Fill Protocol

/// What to fill a shape with. Each Fill type knows how to draw itself
/// on a Canvas — no switching at the call site.
public protocol Fill {
    func draw(on canvas: any Canvas, path: Path)
    func isEqual(to other: any Fill) -> Bool
    func lerp(to other: any Fill, t: Double) -> any Fill
}

public extension Fill where Self: Equatable {
    func isEqual(to other: any Fill) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

public extension Fill where Self: Equatable & Lerpable {
    func lerp(to other: any Fill, t: Double) -> any Fill {
        guard let other = other as? Self else { return t < 0.5 ? self : other }
        let result: Self = self.lerp(to: other, t: t)
        return result
    }
}

// MARK: - Concrete Fills

public struct ColorFill: Fill, Equatable, Lerpable {
    public var color: Color
    public init(_ color: Color) { self.color = color }
    public func draw(on canvas: any Canvas, path: Path) {
        canvas.fillColor(path, color)
    }
    public func lerp(to other: ColorFill, t: Double) -> ColorFill {
        ColorFill(color.lerp(to: other.color, t: t))
    }
}

public struct GradientFill<G: Gradient>: Fill, Equatable, Lerpable {
    public var gradient: G
    public init(_ gradient: G) { self.gradient = gradient }
    public func draw(on canvas: any Canvas, path: Path) {
        canvas.save()
        canvas.clip(path)
        gradient.draw(on: canvas, in: path.boundingBox)
        canvas.restore()
    }
    public func lerp(to other: GradientFill<G>, t: Double) -> GradientFill<G> {
        GradientFill(gradient.lerp(to: other.gradient, t: t))
    }
}

public struct ImageFill: Fill {
    public var image: ImageSource
    public var fit: ContentFit
    public init(_ image: ImageSource, fit: ContentFit = .cover) { self.image = image; self.fit = fit }
    public func draw(on canvas: any Canvas, path: Path) {
        canvas.save()
        canvas.clip(path)
        canvas.drawImage(image, fit: fit, in: path.boundingBox)
        canvas.restore()
    }
    public func isEqual(to other: any Fill) -> Bool { false }
    public func lerp(to other: any Fill, t: Double) -> any Fill { t < 0.5 ? self : other }
}

// MARK: - Gradient Protocol

/// A gradient that knows how to draw itself on a Canvas within clipped bounds.
public protocol Gradient: Equatable, Lerpable {
    func draw(on canvas: any Canvas, in bounds: Rect)
}

public struct GradientStop: Sendable, Equatable, Lerpable {
    public var color: Color
    public var location: Double
    public init(_ color: Color, at location: Double) { self.color = color; self.location = location }
    public func lerp(to other: GradientStop, t: Double) -> GradientStop {
        GradientStop(color.lerp(to: other.color, t: t), at: location.lerp(to: other.location, t: t))
    }
}

public struct LinearGradient: Sendable, Equatable, Gradient {
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
    public func draw(on canvas: any Canvas, in bounds: Rect) {
        canvas.drawLinearGradient(stops: stops, start: start, end: end, in: bounds)
    }
    public func lerp(to other: LinearGradient, t: Double) -> LinearGradient {
        LinearGradient(stops: lerpStops(stops, other.stops, t: t), start: start.lerp(to: other.start, t: t), end: end.lerp(to: other.end, t: t))
    }
}

public struct RadialGradient: Sendable, Equatable, Gradient {
    public var stops: [GradientStop]
    public var center: Vec2
    public var radius: Double
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), radius: Double = 0.5) {
        self.stops = stops; self.center = center; self.radius = radius
    }
    public func draw(on canvas: any Canvas, in bounds: Rect) {
        canvas.drawRadialGradient(stops: stops, center: center, radius: radius, in: bounds)
    }
    public func lerp(to other: RadialGradient, t: Double) -> RadialGradient {
        RadialGradient(stops: lerpStops(stops, other.stops, t: t), center: center.lerp(to: other.center, t: t), radius: radius.lerp(to: other.radius, t: t))
    }
}

public struct AngularGradient: Sendable, Equatable, Gradient {
    public var stops: [GradientStop]
    public var center: Vec2
    public var startAngle: Double
    public var endAngle: Double
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), startAngle: Double = 0, endAngle: Double = .pi * 2) {
        self.stops = stops; self.center = center; self.startAngle = startAngle; self.endAngle = endAngle
    }
    public func draw(on canvas: any Canvas, in bounds: Rect) {
        canvas.drawAngularGradient(stops: stops, center: center, startAngle: startAngle, endAngle: endAngle, in: bounds)
    }
    public func lerp(to other: AngularGradient, t: Double) -> AngularGradient {
        AngularGradient(stops: lerpStops(stops, other.stops, t: t), center: center.lerp(to: other.center, t: t),
                        startAngle: startAngle.lerp(to: other.startAngle, t: t), endAngle: endAngle.lerp(to: other.endAngle, t: t))
    }
}

private func lerpStops(_ a: [GradientStop], _ b: [GradientStop], t: Double) -> [GradientStop] {
    let maxCount = max(a.count, b.count)
    return (0..<maxCount).map { i in
        let sa = a[min(i, a.count - 1)]
        let sb = b[min(i, b.count - 1)]
        return sa.lerp(to: sb, t: t)
    }
}

/// Liquid-Glass material variant. Maps to `UIGlassEffect` on iOS 26+.
public enum GlassStyle: Sendable, Equatable {
    case regular, prominent, clear
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

    public func rect(for contentSize: Size, in bounds: Rect) -> Rect {
        switch self {
        case .fill: return bounds
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

public struct Shader: Equatable, Lerpable {
    public init() {}
    public func lerp(to other: Shader, t: Double) -> Shader { other }
}

// MARK: - Paint

public struct Paint {
    public var fill: any Fill
    public var blendMode: BlendMode
    public var opacity: Double

    public init(_ fill: any Fill, blendMode: BlendMode = .normal, opacity: Double = 1) {
        self.fill = fill; self.blendMode = blendMode; self.opacity = opacity
    }

    public static func color(_ color: Color) -> Paint { Paint(ColorFill(color)) }
    public static func gradient<G: Gradient>(_ gradient: G) -> Paint { Paint(GradientFill(gradient)) }

    public func isEqual(to other: Paint) -> Bool {
        fill.isEqual(to: other.fill) && blendMode == other.blendMode && opacity == other.opacity
    }

    public func lerp(to other: Paint, t: Double) -> Paint {
        Paint(fill.lerp(to: other.fill, t: t),
              blendMode: t < 0.5 ? blendMode : other.blendMode,
              opacity: opacity.lerp(to: other.opacity, t: t))
    }
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

public struct Stroke: Sendable, Equatable, Lerpable {
    public var width: Double
    public var cap: StrokeCap
    public var join: StrokeJoin
    public var alignment: Double
    public var miterLimit: Double
    public var dash: Dash?

    public init(width: Double = 1, cap: StrokeCap = .round, join: StrokeJoin = .round, alignment: Double = 0.5, miterLimit: Double = 10, dash: Dash? = nil) {
        self.width = width; self.cap = cap; self.join = join; self.alignment = alignment; self.miterLimit = miterLimit; self.dash = dash
    }

    public func lerp(to other: Stroke, t: Double) -> Stroke {
        Stroke(width: width.lerp(to: other.width, t: t),
               cap: t < 0.5 ? cap : other.cap,
               join: t < 0.5 ? join : other.join,
               alignment: alignment.lerp(to: other.alignment, t: t),
               miterLimit: miterLimit.lerp(to: other.miterLimit, t: t),
               dash: t < 0.5 ? dash : other.dash)
    }
}

public enum StrokeCap: Sendable, Equatable {
    case butt, round, square
    #if canImport(CoreGraphics)
    public var cgLineCap: CGLineCap { switch self { case .butt: .butt; case .round: .round; case .square: .square } }
    #endif
}

public enum StrokeJoin: Sendable, Equatable {
    case miter, round, bevel
    #if canImport(CoreGraphics)
    public var cgLineJoin: CGLineJoin { switch self { case .miter: .miter; case .round: .round; case .bevel: .bevel } }
    #endif
}

public struct Dash: Sendable, Equatable {
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

// MARK: - SurfaceContext

/// Everything a Layer needs to render. Populated once by SurfaceRenderer,
/// shared across all layers in one pass.
public struct SurfaceContext {
    public let canvas: any Canvas
    public let path: Path
    public let bounds: Rect
}

// MARK: - Layer Protocol

/// A renderable operation in a Surface. Layers are value types with
/// inspectable data. Each layer knows how to compare and interpolate itself.
public protocol Layer {
    func render(in context: SurfaceContext)
    func isEqual(to other: any Layer) -> Bool
    func lerp(to other: any Layer, t: Double) -> any Layer
}

public extension Layer where Self: Equatable {
    func isEqual(to other: any Layer) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

public extension Layer where Self: Equatable & Lerpable {
    func lerp(to other: any Layer, t: Double) -> any Layer {
        guard let other = other as? Self else { return t < 0.5 ? self : other }
        let result: Self = self.lerp(to: other, t: t)
        return result
    }
}

// MARK: - Built-in Layers

public struct FillLayer: Layer, Equatable, Lerpable {
    public var paint: Paint
    public init(_ paint: Paint) { self.paint = paint }

    public func render(in context: SurfaceContext) {
        context.canvas.draw(context.path, with: paint)
    }

    public static func ==(lhs: FillLayer, rhs: FillLayer) -> Bool {
        lhs.paint.isEqual(to: rhs.paint)
    }

    public func lerp(to other: FillLayer, t: Double) -> FillLayer {
        FillLayer(paint.lerp(to: other.paint, t: t))
    }
}

public struct StrokeLayer: Layer, Equatable, Lerpable {
    public var stroke: Stroke
    public var paint: Paint
    public init(_ stroke: Stroke, _ paint: Paint) { self.stroke = stroke; self.paint = paint }

    public func render(in context: SurfaceContext) {
        var expanded = context.path
        if let dash = stroke.dash {
            expanded = expanded.dashed(phase: dash.phase, lengths: dash.pattern)
        }
        expanded = expanded.stroked(width: stroke.width, cap: stroke.cap, join: stroke.join, miterLimit: stroke.miterLimit)
        context.canvas.draw(expanded, with: paint)
    }

    public static func ==(lhs: StrokeLayer, rhs: StrokeLayer) -> Bool {
        lhs.stroke == rhs.stroke && lhs.paint.isEqual(to: rhs.paint)
    }

    public func lerp(to other: StrokeLayer, t: Double) -> StrokeLayer {
        StrokeLayer(stroke.lerp(to: other.stroke, t: t), paint.lerp(to: other.paint, t: t))
    }
}

public struct ShadowLayer: Layer, Equatable, Lerpable {
    public var color: Color
    public var offset: Vec2
    public var blur: Double
    public init(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) {
        self.color = color; self.offset = offset; self.blur = blur
    }

    public func render(in context: SurfaceContext) {
        context.canvas.save()
        context.canvas.filter(.shadow(color: color, offset: offset, blur: blur))
        context.canvas.draw(context.path, with: .color(color))
        context.canvas.restore()
    }

    public func lerp(to other: ShadowLayer, t: Double) -> ShadowLayer {
        ShadowLayer(color: color.lerp(to: other.color, t: t),
                     offset: offset.lerp(to: other.offset, t: t),
                     blur: blur.lerp(to: other.blur, t: t))
    }
}

public struct TransformLayer: Layer, Equatable, Lerpable {
    public var sx: Double
    public var sy: Double
    public var rotation: Double
    public var tx: Double
    public var ty: Double
    public var children: [any Layer]

    public init(sx: Double = 1, sy: Double = 1, rotation: Double = 0, tx: Double = 0, ty: Double = 0, children: [any Layer]) {
        self.sx = sx; self.sy = sy; self.rotation = rotation
        self.tx = tx; self.ty = ty; self.children = children
    }

    public func render(in context: SurfaceContext) {
        context.canvas.save()
        let cx = context.bounds.midX, cy = context.bounds.midY
        context.canvas.translate(cx + tx, cy + ty)
        context.canvas.rotate(rotation)
        context.canvas.scale(sx, sy)
        context.canvas.translate(-cx, -cy)
        for child in children { child.render(in: context) }
        context.canvas.restore()
    }

    public static func ==(lhs: TransformLayer, rhs: TransformLayer) -> Bool {
        lhs.sx == rhs.sx && lhs.sy == rhs.sy && lhs.rotation == rhs.rotation &&
        lhs.tx == rhs.tx && lhs.ty == rhs.ty && layersEqual(lhs.children, rhs.children)
    }

    public func lerp(to other: TransformLayer, t: Double) -> TransformLayer {
        TransformLayer(
            sx: sx.lerp(to: other.sx, t: t), sy: sy.lerp(to: other.sy, t: t),
            rotation: rotation.lerp(to: other.rotation, t: t),
            tx: tx.lerp(to: other.tx, t: t), ty: ty.lerp(to: other.ty, t: t),
            children: lerpLayers(children, other.children, t: t))
    }
}

public struct ClipLayer: Layer, Equatable, Lerpable {
    public var clipShape: any Shape
    public var children: [any Layer]
    public init(clipShape: any Shape, children: [any Layer]) {
        self.clipShape = clipShape; self.children = children
    }

    public func render(in context: SurfaceContext) {
        context.canvas.save()
        context.canvas.clip(clipShape.path(in: context.bounds))
        for child in children { child.render(in: context) }
        context.canvas.restore()
    }

    public static func ==(lhs: ClipLayer, rhs: ClipLayer) -> Bool {
        lhs.clipShape.isEqual(to: rhs.clipShape) && layersEqual(lhs.children, rhs.children)
    }

    public func lerp(to other: ClipLayer, t: Double) -> ClipLayer {
        ClipLayer(clipShape: clipShape.lerp(to: other.clipShape, t: t),
                  children: lerpLayers(children, other.children, t: t))
    }
}

public struct FadeLayer: Layer, Equatable, Lerpable {
    public var opacity: Double
    public var children: [any Layer]
    public init(opacity: Double, children: [any Layer]) {
        self.opacity = opacity; self.children = children
    }

    public func render(in context: SurfaceContext) {
        context.canvas.save()
        context.canvas.setAlpha(opacity)
        for child in children { child.render(in: context) }
        context.canvas.restore()
    }

    public static func ==(lhs: FadeLayer, rhs: FadeLayer) -> Bool {
        lhs.opacity == rhs.opacity && layersEqual(lhs.children, rhs.children)
    }

    public func lerp(to other: FadeLayer, t: Double) -> FadeLayer {
        FadeLayer(opacity: opacity.lerp(to: other.opacity, t: t),
                  children: lerpLayers(children, other.children, t: t))
    }
}

public struct BlendLayer: Layer, Equatable, Lerpable {
    public var mode: BlendMode
    public var children: [any Layer]
    public init(mode: BlendMode, children: [any Layer]) {
        self.mode = mode; self.children = children
    }

    public func render(in context: SurfaceContext) {
        context.canvas.save()
        context.canvas.setBlendMode(mode)
        for child in children { child.render(in: context) }
        context.canvas.restore()
    }

    public static func ==(lhs: BlendLayer, rhs: BlendLayer) -> Bool {
        lhs.mode == rhs.mode && layersEqual(lhs.children, rhs.children)
    }

    public func lerp(to other: BlendLayer, t: Double) -> BlendLayer {
        BlendLayer(mode: t < 0.5 ? mode : other.mode,
                   children: lerpLayers(children, other.children, t: t))
    }
}

// MARK: - Layer helpers

private func layersEqual(_ a: [any Layer], _ b: [any Layer]) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).allSatisfy { $0.isEqual(to: $1) }
}

private func lerpLayers(_ a: [any Layer], _ b: [any Layer], t: Double) -> [any Layer] {
    let maxCount = max(a.count, b.count)
    return (0..<maxCount).map { i in
        if i < a.count && i < b.count { return a[i].lerp(to: b[i], t: t) }
        return i < b.count ? b[i] : a[i]
    }
}

// MARK: - Surface

/// A styled surface. An ordered list of layers — pure data, no closures.
///
/// ```swift
/// let card = Surface()
///     .color(.white)
///     .shadow(color: .black, blur: 8)
///     .border(.gray)
/// ```
public struct Surface {
    public var layers: [any Layer]
    public private(set) var primaryColor: Color?
    public private(set) var glassStyle: GlassStyle?

    public init() { self.layers = [] }

    nonisolated(unsafe) public static let empty = Surface()

    // MARK: - Static factories

    public static func color(_ color: Color) -> Surface { Surface().color(color) }
    public static func gradient<G: Gradient>(_ gradient: G) -> Surface { Surface().gradient(gradient) }
    public static func border(_ color: Color, width: Double = 1) -> Surface { Surface().border(color, width: width) }
    public static func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) -> Surface { Surface().shadow(color: color, offset: offset, blur: blur) }
    public static func glass(_ style: GlassStyle = .regular) -> Surface { Surface().glass(style) }

    // MARK: - Fill

    public func color(_ color: Color) -> Surface {
        var copy = self
        if copy.primaryColor == nil { copy.primaryColor = color }
        copy.layers.append(FillLayer(Paint.color(color)))
        return copy
    }

    public func gradient<G: Gradient>(_ gradient: G) -> Surface {
        var copy = self
        copy.layers.append(FillLayer(Paint.gradient(gradient)))
        return copy
    }

    public func image(_ image: ImageSource, fit: ContentFit = .cover) -> Surface {
        var copy = self
        copy.layers.append(FillLayer(Paint(ImageFill(image, fit: fit))))
        return copy
    }

    // MARK: - Glass

    public func glass(_ style: GlassStyle = .regular) -> Surface {
        var copy = self
        copy.glassStyle = style
        return copy
    }

    // MARK: - Stroke

    public func stroke(_ stroke: Stroke, _ paint: Paint) -> Surface {
        var copy = self
        copy.layers.append(StrokeLayer(stroke, paint))
        return copy
    }

    public func border(_ color: Color, width: Double = 1) -> Surface {
        stroke(Stroke(width: width), .color(color))
    }

    // MARK: - Shadow

    public func shadow(color: Color = Color(0, 0, 0, 0.3), offset: Vec2 = Vec2(0, 4), blur: Double = 8) -> Surface {
        var copy = self
        copy.layers.append(ShadowLayer(color: color, offset: offset, blur: blur))
        return copy
    }

    // MARK: - Transforms (wrap prior layers)

    public func clip(_ clipShape: any Shape) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [ClipLayer(clipShape: clipShape, children: layers)]
        return copy
    }

    public func scale(_ sx: Double, _ sy: Double? = nil) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [TransformLayer(sx: sx, sy: sy ?? sx, children: layers)]
        return copy
    }

    public func translate(_ dx: Double, _ dy: Double) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [TransformLayer(tx: dx, ty: dy, children: layers)]
        return copy
    }

    public func rotate(_ radians: Double) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [TransformLayer(rotation: radians, children: layers)]
        return copy
    }

    public func fade(_ alpha: Double) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [FadeLayer(opacity: alpha, children: layers)]
        return copy
    }

    public func blend(_ mode: BlendMode) -> Surface {
        var copy = Surface()
        copy.primaryColor = primaryColor; copy.glassStyle = glassStyle
        copy.layers = [BlendLayer(mode: mode, children: layers)]
        return copy
    }

    // MARK: - Equality & Lerp

    public func isEqual(to other: Surface) -> Bool {
        layersEqual(layers, other.layers) && primaryColor == other.primaryColor && glassStyle == other.glassStyle
    }

    public func lerp(to other: Surface, t: Double) -> Surface {
        var result = Surface()
        result.layers = lerpLayers(layers, other.layers, t: t)
        if let a = primaryColor, let b = other.primaryColor {
            result.primaryColor = a.lerp(to: b, t: t)
        } else {
            result.primaryColor = t < 0.5 ? primaryColor : other.primaryColor
        }
        result.glassStyle = t < 0.5 ? glassStyle : other.glassStyle
        return result
    }
}

// MARK: - SurfaceRenderer

public struct SurfaceRenderer {
    public let surface: Surface
    public let shape: any Shape
    public let bounds: Rect

    public init(surface: Surface, shape: any Shape, bounds: Rect) {
        self.surface = surface
        self.shape = shape
        self.bounds = bounds
    }

    public func render(on canvas: any Canvas) {
        let basePath = shape.path(in: bounds)
        let context = SurfaceContext(canvas: canvas, path: basePath, bounds: bounds)
        for layer in surface.layers {
            layer.render(in: context)
        }
    }
}
