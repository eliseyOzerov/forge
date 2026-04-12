import CoreGraphics

/// Converts an SVGDocument into a Surface by walking the element tree
/// and producing layers for each SVG element's fill and stroke.
public struct SVGSurfaceBuilder {
    public let document: SVGDocument
    public let overrides: [String: GraphicOverride]
    public let globalColor: Color?

    public init(document: SVGDocument, overrides: [String: GraphicOverride] = [:], globalColor: Color? = nil) {
        self.document = document
        self.overrides = overrides
        self.globalColor = globalColor
    }

    /// Build a Surface that renders the entire SVG, fitted into whatever
    /// bounds it's given (viewBox scaling is baked into a transform layer).
    public func build() -> Surface {
        Surface(layers: [ViewBoxLayer(document: document, overrides: overrides, globalColor: globalColor, elements: document.elements)])
    }
}

// MARK: - GraphicOverride

public struct GraphicOverride {
    public var fill: Color?
    public var stroke: Color?
    public var strokeWidth: CGFloat?
    public var opacity: CGFloat?
    public var isHidden: Bool

    public init(fill: Color? = nil, stroke: Color? = nil, strokeWidth: CGFloat? = nil, opacity: CGFloat? = nil, isHidden: Bool = false) {
        self.fill = fill; self.stroke = stroke; self.strokeWidth = strokeWidth; self.opacity = opacity; self.isHidden = isHidden
    }
}

// MARK: - ViewBox Layer

/// Top-level layer that applies viewBox → canvas scaling then renders elements.
#if canImport(UIKit)
import UIKit

struct ViewBoxLayer: Layer {
    let document: SVGDocument
    let overrides: [String: GraphicOverride]
    let globalColor: Color?
    let elements: [SVGElement]

    func render(in ctx: CGContext, path: CGPath, bounds: CGRect) {
        let vb = document.viewBox
        guard vb.width > 0, vb.height > 0 else { return }

        let scaleX = bounds.width / vb.width, scaleY = bounds.height / vb.height
        let scale = min(scaleX, scaleY)
        let offsetX = (bounds.width - vb.width * scale) / 2
        let offsetY = (bounds.height - vb.height * scale) / 2

        ctx.saveGState()
        ctx.translateBy(x: bounds.minX + offsetX, y: bounds.minY + offsetY)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -vb.origin.x, y: -vb.origin.y)

        for element in elements {
            renderElement(element, in: ctx)
        }
        ctx.restoreGState()
    }

    private func renderElement(_ element: SVGElement, in ctx: CGContext) {
        switch element {
        case .path(let data):
            let p = SVGPathDataParser.parse(data.d)
            drawPath(p.cgPath, attributes: data.attributes, id: data.id, in: ctx)
        case .rect(let data):
            let rect = CGRect(x: data.x, y: data.y, width: data.width, height: data.height)
            let cgPath: CGPath
            if data.rx > 0 || data.ry > 0 {
                cgPath = CGPath(roundedRect: rect, cornerWidth: data.rx > 0 ? data.rx : data.ry, cornerHeight: data.ry > 0 ? data.ry : data.rx, transform: nil)
            } else { cgPath = CGPath(rect: rect, transform: nil) }
            drawPath(cgPath, attributes: data.attributes, id: data.id, in: ctx)
        case .circle(let data):
            let rect = CGRect(x: data.cx - data.r, y: data.cy - data.r, width: data.r * 2, height: data.r * 2)
            drawPath(CGPath(ellipseIn: rect, transform: nil), attributes: data.attributes, id: data.id, in: ctx)
        case .ellipse(let data):
            let rect = CGRect(x: data.cx - data.rx, y: data.cy - data.ry, width: data.rx * 2, height: data.ry * 2)
            drawPath(CGPath(ellipseIn: rect, transform: nil), attributes: data.attributes, id: data.id, in: ctx)
        case .line(let data):
            var p = Path(); p.move(to: CGPoint(x: data.x1, y: data.y1)); p.line(to: CGPoint(x: data.x2, y: data.y2))
            var attrs = data.attributes; attrs.fill = .none
            if case .none = attrs.stroke { attrs.stroke = .color(.black) }
            drawPath(p.cgPath, attributes: attrs, id: data.id, in: ctx)
        case .polygon(let data):
            guard !data.points.isEmpty else { return }
            var p = Path(); p.move(to: data.points[0])
            for pt in data.points.dropFirst() { p.line(to: pt) }; p.close()
            drawPath(p.cgPath, attributes: data.attributes, id: data.id, in: ctx)
        case .polyline(let data):
            guard !data.points.isEmpty else { return }
            var p = Path(); p.move(to: data.points[0])
            for pt in data.points.dropFirst() { p.line(to: pt) }
            drawPath(p.cgPath, attributes: data.attributes, id: data.id, in: ctx)
        case .group(let data):
            if overrides[data.id]?.isHidden == true { return }
            ctx.saveGState()
            if data.attributes.transform != .identity { ctx.concatenate(data.attributes.transform) }
            ctx.setAlpha(overrides[data.id]?.opacity ?? CGFloat(data.attributes.opacity))
            for child in data.children { renderElement(child, in: ctx) }
            ctx.restoreGState()
        }
    }

    private func drawPath(_ cgPath: CGPath, attributes: SVGPaintAttributes, id: String, in ctx: CGContext) {
        let ov = overrides[id]
        if ov?.isHidden == true { return }

        ctx.saveGState()
        if attributes.transform != .identity { ctx.concatenate(attributes.transform) }
        ctx.setAlpha(ov?.opacity ?? CGFloat(attributes.opacity))

        if let fillColor = resolveFill(attributes, override: ov) {
            ctx.addPath(cgPath); ctx.setFillColor(fillColor.cgColor); ctx.fillPath()
        }
        if let strokeColor = resolveStroke(attributes, override: ov) {
            ctx.addPath(cgPath)
            ctx.setStrokeColor(strokeColor.cgColor)
            ctx.setLineWidth(ov?.strokeWidth ?? attributes.strokeWidth)
            ctx.setLineCap(attributes.strokeLineCap)
            ctx.setLineJoin(attributes.strokeLineJoin)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private func resolveFill(_ attrs: SVGPaintAttributes, override ov: GraphicOverride?) -> Color? {
        if let c = ov?.fill { return c }
        if let g = globalColor { switch attrs.fill { case .none: return nil; default: return g } }
        return resolveColor(attrs.fill)
    }

    private func resolveStroke(_ attrs: SVGPaintAttributes, override ov: GraphicOverride?) -> Color? {
        if let c = ov?.stroke { return c }
        return resolveColor(attrs.stroke)
    }

    private func resolveColor(_ paint: SVGPaint) -> Color? {
        switch paint { case .none: return nil; case .color(let c): return c; case .currentColor: return globalColor ?? .black }
    }
}

#endif
