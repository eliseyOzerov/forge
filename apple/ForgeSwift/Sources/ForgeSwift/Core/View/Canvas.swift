import Foundation

// MARK: - Canvas Protocol

/// Platform-agnostic 2D drawing interface. The minimal set of
/// operations needed to implement any visual component.
///
/// `draw(_:with:)` is the single drawing primitive. Everything else
/// is context state that affects how draws land on the surface.
///
/// Paint carries fill (color/gradient/image), blend mode, and opacity.
/// Path carries geometry and can expand strokes into fill paths via
/// `stroked(width:cap:join:)`. Shape builds paths from rects.
/// Filter applies post-processing effects.
public protocol Canvas {

    /// Draw a filled path with the given paint.
    func draw(_ path: Path, with paint: Paint)

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

    /// Apply a filter to the current rendering context.
    func filter(_ filter: Filter)
}

// MARK: - Filter

/// Platform-agnostic filter definitions.
public enum Filter {
    case blur(radius: Double)
    case shadow(color: Color, offset: Vec2, blur: Double)
}

// MARK: - Convenience Extensions

public extension Canvas {

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

public final class CGCanvas: Canvas {
    public let ctx: CGContext

    public init(_ ctx: CGContext) {
        self.ctx = ctx
    }

    public func draw(_ path: Path, with paint: Paint) {
        ctx.saveGState()
        if paint.opacity < 1 { ctx.setAlpha(paint.opacity) }
        if paint.blendMode != .normal { ctx.setBlendMode(paint.blendMode.cgBlendMode) }

        switch paint.fill {
        case .color(let color):
            ctx.addPath(path.cgPath)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
        case .gradient(let gradient):
            ctx.addPath(path.cgPath)
            ctx.clip()
            drawGradient(gradient, in: path.boundingBox)
        case .image(let image, let fit):
            ctx.addPath(path.cgPath)
            ctx.clip()
            drawImage(image, fit: fit, in: path.boundingBox)
        case .shader:
            break
        }

        ctx.restoreGState()
    }

    public func save() { ctx.saveGState() }
    public func restore() { ctx.restoreGState() }

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
            // CIFilter-based blur would require capturing the context contents.
            // For now, use shadow as an approximation for simple cases.
            _ = radius
        case .shadow(let color, let offset, let blur):
            ctx.setShadow(offset: CGSize(width: offset.x, height: offset.y), blur: blur, color: color.cgColor)
        }
    }

    // MARK: - Gradient rendering

    private func drawGradient(_ gradient: Gradient, in bounds: Rect) {
        switch gradient {
        case .linear(let lg):
            guard let cgGradient = makeCGGradient(stops: lg.stops) else { return }
            let start = CGPoint(x: bounds.x + lg.start.x * bounds.width, y: bounds.y + lg.start.y * bounds.height)
            let end = CGPoint(x: bounds.x + lg.end.x * bounds.width, y: bounds.y + lg.end.y * bounds.height)
            ctx.drawLinearGradient(cgGradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .radial(let rg):
            guard let cgGradient = makeCGGradient(stops: rg.stops) else { return }
            let center = CGPoint(x: bounds.x + rg.center.x * bounds.width, y: bounds.y + rg.center.y * bounds.height)
            let radius = rg.radius * max(bounds.width, bounds.height)
            ctx.drawRadialGradient(cgGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .angular(let ag):
            // Angular gradient requires manual wedge rendering or Metal.
            _ = ag
        }
    }

    private func makeCGGradient(stops: [GradientStop]) -> CGGradient? {
        let colors = stops.map { $0.color.cgColor } as CFArray
        var locations = stops.map { CGFloat($0.location) }
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations)
    }

    // MARK: - Image rendering

    private func drawImage(_ source: ImageSource, fit: ContentFit, in bounds: Rect) {
        #if canImport(UIKit)
        guard let cgImage = source.platformImage.cgImage else { return }
        let imageSize = Size(Double(cgImage.width), Double(cgImage.height))
        let destRect = fit.rect(for: imageSize, in: bounds)
        ctx.draw(cgImage, in: destRect.cgRect)
        #endif
    }
}

#endif
