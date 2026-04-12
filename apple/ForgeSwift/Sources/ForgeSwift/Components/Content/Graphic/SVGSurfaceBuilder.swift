import CoreGraphics

/// Converts an SVGDocument into a Surface using the SurfaceBuilder API.
/// No platform-specific code — just records instructions.
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
        Surface { s in
            for element in document.elements {
                buildElement(element, on: s)
            }
            return s
        }
    }

    // MARK: - Element → Builder calls

    private func buildElement(_ element: SVGElement, on s: Surface) {
        switch element {
        case .path(let data):
            let path = SVGPathDataParser.parse(data.d)
            buildDrawn(Shape({ _ in path }), attributes: data.attributes, id: data.id, on: s)

        case .rect(let data):
            let r = Rect(x: data.x, y: data.y, width: data.width, height: data.height)
            let shape = data.rx > 0 || data.ry > 0
                ? Shape.roundedRect(radius: data.rx > 0 ? data.rx : data.ry).resolve(in: r)
                : Shape.rect().resolve(in: r)
            buildDrawn(Shape({ _ in shape }), attributes: data.attributes, id: data.id, on: s)

        case .circle(let data):
            let r = Rect.fromCircle(center: Point(data.cx, data.cy), radius: data.r)
            let path = Shape.ellipse().resolve(in: r)
            buildDrawn(Shape({ _ in path }), attributes: data.attributes, id: data.id, on: s)

        case .ellipse(let data):
            let r = Rect(x: data.cx - data.rx, y: data.cy - data.ry, width: data.rx * 2, height: data.ry * 2)
            let path = Shape.ellipse().resolve(in: r)
            buildDrawn(Shape({ _ in path }), attributes: data.attributes, id: data.id, on: s)

        case .line(let data):
            var attrs = data.attributes; attrs.fill = .none
            if case .none = attrs.stroke { attrs.stroke = .color(.black) }
            let path = Path.line(from: CGPoint(x: data.x1, y: data.y1), to: CGPoint(x: data.x2, y: data.y2))
            buildDrawn(Shape({ _ in path }), attributes: attrs, id: data.id, on: s)

        case .polygon(let data):
            guard !data.points.isEmpty else { return }
            buildDrawn(Shape({ _ in Path.polygon(data.points) }), attributes: data.attributes, id: data.id, on: s)

        case .polyline(let data):
            guard !data.points.isEmpty else { return }
            buildDrawn(Shape({ _ in Path.polyline(data.points) }), attributes: data.attributes, id: data.id, on: s)

        case .group(let data):
            if overrides[data.id]?.isHidden == true { return }
            let opacity = overrides[data.id]?.opacity ?? Double(data.attributes.opacity)
            let hasTransform = data.attributes.transform != .identity

            s.compose { inner in
                if hasTransform { inner.transform(Transform2D(data.attributes.transform)) }
                if opacity < 1 { inner.fade(opacity) }
                for child in data.children { buildElement(child, on: inner) }
                return inner
            }
        }
    }

    private func buildDrawn(_ shape: Shape, attributes: SVGPaintAttributes, id: String, on s: Surface) {
        let ov = overrides[id]
        if ov?.isHidden == true { return }

        let opacity = ov?.opacity ?? CGFloat(attributes.opacity)
        let hasTransform = attributes.transform != .identity

        if hasTransform || opacity < 1 {
            s.compose { inner in
                if hasTransform { inner.transform(Transform2D(attributes.transform)) }
                if opacity < 1 { inner.fade(opacity) }
                addFillAndStroke(shape, attributes: attributes, ov: ov, on: inner)
                return inner
            }
        } else {
            addFillAndStroke(shape, attributes: attributes, ov: ov, on: s)
        }
    }

    private func addFillAndStroke(_ shape: Shape, attributes: SVGPaintAttributes, ov: GraphicOverride?, on s: Surface) {
        if let fillColor = resolveFill(attributes, override: ov) {
            s.shape({ _ in shape }, .color(fillColor))
        }
        if let strokeColor = resolveStroke(attributes, override: ov) {
            let width = ov?.strokeWidth ?? attributes.strokeWidth
            s.stroke(Stroke(width: width, cap: StrokeCap(attributes.strokeLineCap), join: StrokeJoin(attributes.strokeLineJoin)), .color(strokeColor))
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
    public var strokeWidth: Double?
    public var opacity: Double?
    public var isHidden: Bool

    public init(fill: Color? = nil, stroke: Color? = nil, strokeWidth: Double? = nil, opacity: Double? = nil, isHidden: Bool = false) {
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
