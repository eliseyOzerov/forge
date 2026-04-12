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
