import CoreGraphics

/// Converts an SVGDocument into a Surface by walking the element tree
/// and producing layers using the SurfaceBuilder API. No platform-specific
/// rendering code — the Surface is rendered by SurfaceRenderer.
public struct SVGSurfaceBuilder {
    public let document: SVGDocument
    public let overrides: [String: GraphicOverride]
    public let globalColor: Color?

    public init(document: SVGDocument, overrides: [String: GraphicOverride] = [:], globalColor: Color? = nil) {
        self.document = document
        self.overrides = overrides
        self.globalColor = globalColor
    }

    public func build() -> Surface {
        var elementLayers: [any Layer] = []
        for element in document.elements {
            buildElement(element, into: &elementLayers)
        }

        let vb = document.viewBox
        guard vb.width > 0, vb.height > 0 else { return Surface(layers: elementLayers) }

        // Wrap all element layers in a viewBox → canvas transform
        let viewBoxLayer = TransformLayer(children: elementLayers, apply: { ctx, _, bounds in
            #if canImport(UIKit)
            let scaleX = bounds.width / vb.width, scaleY = bounds.height / vb.height
            let scale = min(scaleX, scaleY)
            let offsetX = (bounds.width - vb.width * scale) / 2
            let offsetY = (bounds.height - vb.height * scale) / 2
            ctx.translateBy(x: bounds.minX + offsetX, y: bounds.minY + offsetY)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -vb.origin.x, y: -vb.origin.y)
            #endif
        }, cleanup: nil)

        return Surface(layers: [viewBoxLayer])
    }

    // MARK: - Element → Layers

    private func buildElement(_ element: SVGElement, into layers: inout [any Layer]) {
        switch element {
        case .path(let data):
            let path = SVGPathDataParser.parse(data.d)
            buildPath(path, attributes: data.attributes, id: data.id, into: &layers)

        case .rect(let data):
            let shape: Shape
            if data.rx > 0 || data.ry > 0 {
                let r = data.rx > 0 ? data.rx : data.ry
                shape = Shape({ _ in
                    var p = Path()
                    p.addRoundedRect(CGRect(x: data.x, y: data.y, width: data.width, height: data.height), cornerWidth: r, cornerHeight: r)
                    return p
                })
            } else {
                shape = Shape({ _ in
                    var p = Path(); p.addRect(CGRect(x: data.x, y: data.y, width: data.width, height: data.height)); return p
                })
            }
            buildShape(shape, attributes: data.attributes, id: data.id, into: &layers)

        case .circle(let data):
            let shape = Shape({ _ in
                var p = Path(); p.addEllipse(in: CGRect(x: data.cx - data.r, y: data.cy - data.r, width: data.r * 2, height: data.r * 2)); return p
            })
            buildShape(shape, attributes: data.attributes, id: data.id, into: &layers)

        case .ellipse(let data):
            let shape = Shape({ _ in
                var p = Path(); p.addEllipse(in: CGRect(x: data.cx - data.rx, y: data.cy - data.ry, width: data.rx * 2, height: data.ry * 2)); return p
            })
            buildShape(shape, attributes: data.attributes, id: data.id, into: &layers)

        case .line(let data):
            var attrs = data.attributes; attrs.fill = .none
            if case .none = attrs.stroke { attrs.stroke = .color(.black) }
            let path = Path.line(from: CGPoint(x: data.x1, y: data.y1), to: CGPoint(x: data.x2, y: data.y2))
            buildPath(path, attributes: attrs, id: data.id, into: &layers)

        case .polygon(let data):
            guard !data.points.isEmpty else { return }
            let path = Path.polygon(data.points)
            buildPath(path, attributes: data.attributes, id: data.id, into: &layers)

        case .polyline(let data):
            guard !data.points.isEmpty else { return }
            let path = Path.polyline(data.points)
            buildPath(path, attributes: data.attributes, id: data.id, into: &layers)

        case .group(let data):
            if overrides[data.id]?.isHidden == true { return }
            var children: [any Layer] = []
            for child in data.children { buildElement(child, into: &children) }

            let opacity = overrides[data.id]?.opacity ?? CGFloat(data.attributes.opacity)
            if data.attributes.transform != .identity || opacity < 1 {
                // Wrap children in a transform+opacity layer
                let t = Transform2D(data.attributes.transform)
                layers.append(TransformLayer(children: children, apply: { ctx, _, _ in
                    #if canImport(UIKit)
                    ctx.concatenate(t.cgAffineTransform)
                    ctx.setAlpha(opacity)
                    #endif
                }, cleanup: nil))
            } else {
                layers.append(contentsOf: children)
            }
        }
    }

    private func buildPath(_ path: Path, attributes: SVGPaintAttributes, id: String, into layers: inout [any Layer]) {
        let shape = Shape({ _ in path })
        buildShape(shape, attributes: attributes, id: id, into: &layers)
    }

    private func buildShape(_ shape: Shape, attributes: SVGPaintAttributes, id: String, into layers: inout [any Layer]) {
        let ov = overrides[id]
        if ov?.isHidden == true { return }

        let opacity = ov?.opacity ?? CGFloat(attributes.opacity)
        let paint = { (fill: Fill) -> Paint in
            Paint(fill, opacity: opacity)
        }

        // Fill
        if let fillColor = resolveFill(attributes, override: ov) {
            if attributes.transform != .identity {
                // Wrap in transform
                let t = Transform2D(attributes.transform)
                layers.append(TransformLayer(children: [ShapeLayer(shape, paint(.color(fillColor)))], apply: { ctx, _, _ in
                    #if canImport(UIKit)
                    ctx.concatenate(t.cgAffineTransform)
                    #endif
                }, cleanup: nil))
            } else {
                layers.append(ShapeLayer(shape, paint(.color(fillColor))))
            }
        }

        // Stroke
        if let strokeColor = resolveStroke(attributes, override: ov) {
            let width = ov?.strokeWidth ?? attributes.strokeWidth
            let stroke = Stroke(width: width,
                                cap: StrokeCap(attributes.strokeLineCap),
                                join: StrokeJoin(attributes.strokeLineJoin))
            if attributes.transform != .identity {
                let t = Transform2D(attributes.transform)
                layers.append(TransformLayer(children: [StrokeLayer(stroke, paint(.color(strokeColor)))], apply: { ctx, _, _ in
                    #if canImport(UIKit)
                    ctx.concatenate(t.cgAffineTransform)
                    #endif
                }, cleanup: nil))
            } else {
                layers.append(StrokeLayer(stroke, paint(.color(strokeColor))))
            }
        }
    }

    // MARK: - Color Resolution

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

// MARK: - Helpers

extension StrokeCap {
    init(_ cgLineCap: CGLineCap) {
        switch cgLineCap { case .butt: self = .butt; case .round: self = .round; case .square: self = .square; @unknown default: self = .butt }
    }
}

extension StrokeJoin {
    init(_ cgLineJoin: CGLineJoin) {
        switch cgLineJoin { case .miter: self = .miter; case .round: self = .round; case .bevel: self = .bevel; @unknown default: self = .miter }
    }
}
