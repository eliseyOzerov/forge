import Foundation

// MARK: - Canvas Protocol

/// Platform-agnostic 2D drawing interface. Exposes low-level primitives
/// that Fill and Gradient types compose to render themselves.
///
/// State operations (save/restore, transforms, clip) affect subsequent draws.
/// Drawing primitives (fillColor, drawLinearGradient, etc.) produce output.
public protocol Canvas: AnyObject {

    // MARK: Drawing primitives

    /// Fill a path with a solid color.
    func fillColor(_ path: Path, _ color: Color)

    /// Draw a linear gradient within bounds. Caller is responsible for clipping first.
    func drawLinearGradient(stops: [GradientStop], start: Vec2, end: Vec2, in bounds: Rect)

    /// Draw a radial gradient within bounds. Caller is responsible for clipping first.
    func drawRadialGradient(stops: [GradientStop], center: Vec2, radius: Double, in bounds: Rect)

    /// Draw an angular gradient within bounds. Caller is responsible for clipping first.
    func drawAngularGradient(stops: [GradientStop], center: Vec2, startAngle: Double, endAngle: Double, in bounds: Rect)

    /// Draw an image within bounds. Caller is responsible for clipping first.
    func drawImage(_ source: ImageSource, fit: ContentFit, in bounds: Rect)

    // MARK: State

    /// Push the current state (transform, clip) onto the stack.
    func save()
    /// Pop and restore the most recently saved state.
    func restore()

    // MARK: Transforms

    func translate(_ dx: Double, _ dy: Double)
    func rotate(_ radians: Double)
    func scale(_ sx: Double, _ sy: Double)
    func transform(_ transform: Transform2D)

    // MARK: Clipping

    /// Intersect the current clip region with the given path.
    func clip(_ path: Path)

    // MARK: Filters

    /// Set global alpha for subsequent draws (multiplies with paint opacity).
    func setAlpha(_ alpha: Double)

    /// Set blend mode for subsequent draws (overrides paint blend mode).
    func setBlendMode(_ mode: BlendMode)

    /// Apply a filter to the current rendering context.
    func filter(_ filter: Filter)
}

// MARK: - Filter

/// Platform-agnostic filter definitions.
public enum Filter {
    case blur(radius: Double)
    case shadow(color: Color, offset: Vec2, blur: Double)
}

// MARK: - Convenience: draw with Paint

public extension Canvas {

    /// Draw a filled path with full paint (fill + blend + opacity).
    /// Delegates to `paint.fill.draw(on:path:)` after setting up state.
    func draw(_ path: Path, with paint: Paint) {
        save()
        if paint.opacity < 1 { setAlpha(paint.opacity) }
        if paint.blendMode != .normal { setBlendMode(paint.blendMode) }
        paint.fill.draw(on: self, path: path)
        restore()
    }

    // MARK: Fill shortcuts

    func fillRect(_ rect: Rect, paint: Paint) {
        var p = Path(); p.addRect(rect)
        draw(p, with: paint)
    }

    func fillRect(_ rect: Rect, color: Color) {
        fillRect(rect, paint: .color(color))
    }

    func fillEllipse(in rect: Rect, paint: Paint) {
        var p = Path(); p.addEllipse(in: rect)
        draw(p, with: paint)
    }

    func fillEllipse(in rect: Rect, color: Color) {
        fillEllipse(in: rect, paint: .color(color))
    }

    func fillCircle(center: Vec2, radius: Double, paint: Paint) {
        let rect = Rect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        fillEllipse(in: rect, paint: paint)
    }

    func fillCircle(center: Vec2, radius: Double, color: Color) {
        fillCircle(center: center, radius: radius, paint: .color(color))
    }

    func fillRoundedRect(_ rect: Rect, radius: Double, paint: Paint) {
        var p = Path(); p.addRoundedRect(rect, cornerWidth: radius, cornerHeight: radius)
        draw(p, with: paint)
    }

    func fillRoundedRect(_ rect: Rect, radius: Double, color: Color) {
        fillRoundedRect(rect, radius: radius, paint: .color(color))
    }

    // MARK: Stroke shortcuts (convert stroke to fill path)

    func strokeCircle(center: Vec2, radius: Double, color: Color, width: Double = 1) {
        let rect = Rect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        var p = Path(); p.addEllipse(in: rect)
        let stroked = p.stroked(width: width, cap: StrokeCap.butt, join: StrokeJoin.miter)
        draw(stroked, with: .color(color))
    }

    func strokeArc(center: Vec2, radius: Double, start: Double, sweep: Double, color: Color, width: Double = 1, cap: StrokeCap = .round) {
        var p = Path()
        let endAngle = start + sweep
        p.arc(center: Point(center.x, center.y), radius: radius, startAngle: start, endAngle: endAngle, clockwise: sweep < 0)
        let stroked = p.stroked(width: width, cap: cap, join: StrokeJoin.miter)
        draw(stroked, with: .color(color))
    }
}

// MARK: - CGCanvas (CoreGraphics implementation)

#if canImport(CoreGraphics)
import CoreGraphics

/// CoreGraphics implementation of the Canvas protocol.
public final class CGCanvas: Canvas {
    public let ctx: CGContext

    public init(_ ctx: CGContext) {
        self.ctx = ctx
    }

    // MARK: Drawing primitives

    public func fillColor(_ path: Path, _ color: Color) {
        ctx.addPath(path.cgPath)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    public func drawLinearGradient(stops: [GradientStop], start: Vec2, end: Vec2, in bounds: Rect) {
        guard let cgGradient = makeCGGradient(stops: stops) else { return }
        let startPt = CGPoint(x: bounds.x + start.x * bounds.width, y: bounds.y + start.y * bounds.height)
        let endPt = CGPoint(x: bounds.x + end.x * bounds.width, y: bounds.y + end.y * bounds.height)
        ctx.drawLinearGradient(cgGradient, start: startPt, end: endPt, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    public func drawRadialGradient(stops: [GradientStop], center: Vec2, radius: Double, in bounds: Rect) {
        guard let cgGradient = makeCGGradient(stops: stops) else { return }
        let centerPt = CGPoint(x: bounds.x + center.x * bounds.width, y: bounds.y + center.y * bounds.height)
        let r = radius * max(bounds.width, bounds.height)
        ctx.drawRadialGradient(cgGradient, startCenter: centerPt, startRadius: 0, endCenter: centerPt, endRadius: r, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    public func drawAngularGradient(stops: [GradientStop], center: Vec2, startAngle: Double, endAngle: Double, in bounds: Rect) {
        // Angular gradient requires manual wedge rendering or Metal.
        _ = (stops, center, startAngle, endAngle, bounds)
    }

    public func drawImage(_ source: ImageSource, fit: ContentFit, in bounds: Rect) {
        #if canImport(UIKit)
        guard let cgImage = source.platformImage.cgImage else { return }
        let imageSize = Size(Double(cgImage.width), Double(cgImage.height))
        let destRect = fit.rect(for: imageSize, in: bounds)
        ctx.draw(cgImage, in: destRect.cgRect)
        #endif
    }

    // MARK: State

    public func save() { ctx.saveGState() }
    public func restore() { ctx.restoreGState() }

    public func setAlpha(_ alpha: Double) { ctx.setAlpha(alpha) }
    public func setBlendMode(_ mode: BlendMode) { ctx.setBlendMode(mode.cgBlendMode) }

    public func translate(_ dx: Double, _ dy: Double) { ctx.translateBy(x: dx, y: dy) }
    public func rotate(_ radians: Double) { ctx.rotate(by: radians) }
    public func scale(_ sx: Double, _ sy: Double) { ctx.scaleBy(x: sx, y: sy) }
    public func transform(_ transform: Transform2D) { ctx.concatenate(transform.cgAffineTransform) }

    public func clip(_ path: Path) {
        ctx.addPath(path.cgPath)
        ctx.clip()
    }

    public func filter(_ filter: Filter) {
        switch filter {
        case .blur(let radius):
            _ = radius
        case .shadow(let color, let offset, let blur):
            ctx.setShadow(offset: CGSize(width: offset.x, height: offset.y), blur: blur, color: color.cgColor)
        }
    }

    // MARK: Internal

    private func makeCGGradient(stops: [GradientStop]) -> CGGradient? {
        let colors = stops.map { $0.color.cgColor } as CFArray
        var locations = stops.map { CGFloat($0.location) }
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations)
    }
}

#endif
