import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

#if canImport(CoreText)
import CoreText
#endif

// MARK: - SVG Document

/// Parsed SVG document with a viewBox, element tree, and definitions registry.
@Init
public struct SVGDocument {
    public var viewBox: CGRect
    public var elements: [SVGElement]
    public var defs: SVGDefs = SVGDefs()

    public var elementIDs: [String] {
        elements.flatMap { $0.collectIDs() }
    }
}

// MARK: - SVGDefs

/// Registry of reusable definitions (<defs>, gradients, clipPaths, filters, masks).
public struct SVGDefs {
    public var linearGradients: [String: SVGLinearGradientDef] = [:]
    public var radialGradients: [String: SVGRadialGradientDef] = [:]
    public var clipPaths: [String: [SVGElement]] = [:]
    public var filters: [String: SVGFilterDef] = [:]
    public var masks: [String: SVGMaskDef] = [:]
    public var reusableElements: [String: [SVGElement]] = [:]
    public init() {}
}

// MARK: - SVGElement

/// A single SVG shape, group, text, image, or use element.
public indirect enum SVGElement {
    case path(SVGPathData)
    case rect(SVGRectData)
    case circle(SVGCircleData)
    case ellipse(SVGEllipseData)
    case line(SVGLineData)
    case polygon(SVGPolygonData)
    case polyline(SVGPolygonData)
    case group(SVGGroupData)
    case use(SVGUseData)
    case image(SVGImageData)
    case text(SVGTextData)

    func collectIDs() -> [String] {
        switch self {
        case .path(let d): [d.id]
        case .rect(let d): [d.id]
        case .circle(let d): [d.id]
        case .ellipse(let d): [d.id]
        case .line(let d): [d.id]
        case .polygon(let d): [d.id]
        case .polyline(let d): [d.id]
        case .group(let d): [d.id] + d.children.flatMap { $0.collectIDs() }
        case .use(let d): [d.id]
        case .image(let d): [d.id]
        case .text(let d): [d.id]
        }
    }
}

// MARK: - Paint Attributes

/// Common SVG presentation attributes for fill, stroke, opacity, and transform.
@Init
public struct SVGPaintAttributes {
    // Fill
    public var fill: SVGPaint = .color(.black)
    public var fillOpacity: Double = 1
    public var fillRule: FillRule = .winding
    // Stroke
    public var stroke: SVGPaint = .none
    public var strokeWidth: CGFloat = 1
    public var strokeLineCap: CGLineCap = .butt
    public var strokeLineJoin: CGLineJoin = .miter
    public var strokeMiterLimit: CGFloat = 4
    public var strokeDashArray: [CGFloat] = []
    public var strokeDashOffset: CGFloat = 0
    public var strokeOpacity: Double = 1
    // Shared
    public var opacity: Double = 1
    public var transform: CGAffineTransform = .identity
    public var visibility: SVGVisibility = .visible
    public var display: SVGDisplay = .inline
    // References
    public var clipPathID: String? = nil
    public var filterID: String? = nil
    public var maskID: String? = nil

    nonisolated(unsafe) public static let defaults = SVGPaintAttributes()
}

/// SVG paint value: none, solid color, currentColor, or a url reference (gradient/pattern).
public enum SVGPaint: Equatable {
    case none
    case color(Color)
    case currentColor
    case url(String)
}

/// SVG visibility property.
public enum SVGVisibility: Sendable, Equatable { case visible, hidden, collapse }

/// SVG display property.
public enum SVGDisplay: Sendable, Equatable { case inline, none }

// MARK: - Element Data

/// Data for an SVG `<path>` element.
@Init
public struct SVGPathData {
    public let id: String
    public let d: String
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<rect>` element.
@Init
public struct SVGRectData {
    public let id: String
    public let x, y, width, height, rx, ry: CGFloat
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<circle>` element.
@Init
public struct SVGCircleData {
    public let id: String
    public let cx, cy, r: CGFloat
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<ellipse>` element.
@Init
public struct SVGEllipseData {
    public let id: String
    public let cx, cy, rx, ry: CGFloat
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<line>` element.
@Init
public struct SVGLineData {
    public let id: String
    public let x1, y1, x2, y2: CGFloat
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<polygon>` or `<polyline>` element.
@Init
public struct SVGPolygonData {
    public let id: String
    public let points: [Point]
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<g>` group element with children.
@Init
public struct SVGGroupData {
    public let id: String
    public let attributes: SVGPaintAttributes
    public let children: [SVGElement]
}

/// Data for an SVG `<use>` element referencing a defs entry.
@Init
public struct SVGUseData {
    public let id: String
    public let href: String
    public let x: CGFloat
    public let y: CGFloat
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<image>` element.
@Init
public struct SVGImageData {
    public let id: String
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    public let href: String
    public let attributes: SVGPaintAttributes
}

/// Data for an SVG `<text>` element.
@Init
public struct SVGTextData {
    public let id: String
    public let x: CGFloat
    public let y: CGFloat
    public let fontSize: CGFloat
    public let fontFamily: String
    public let fontWeight: String
    public let textAnchor: SVGTextAnchor
    public let attributes: SVGPaintAttributes
    public let spans: [SVGTextSpan]
}

/// A span of text within an SVG `<text>` element.
@Init
public struct SVGTextSpan {
    public let text: String
    public let x: CGFloat?
    public let y: CGFloat?
    public let dx: CGFloat
    public let dy: CGFloat
    public let fontSize: CGFloat?
    public let fontWeight: String?
    public let attributes: SVGPaintAttributes?
}

/// Text alignment anchor.
public enum SVGTextAnchor: Sendable, Equatable { case start, middle, end }

// MARK: - Gradient Definitions

/// A parsed gradient stop.
@Init
public struct SVGGradientStop {
    public let offset: Double
    public let color: Color
    public let opacity: Double
}

/// Parsed `<linearGradient>` definition.
public struct SVGLinearGradientDef {
    public var id: String
    public var x1: Double = 0
    public var y1: Double = 0
    public var x2: Double = 1
    public var y2: Double = 0
    public var gradientUnits: SVGGradientUnits = .objectBoundingBox
    public var gradientTransform: CGAffineTransform = .identity
    public var stops: [SVGGradientStop] = []
    public var href: String? = nil
    public init(id: String) { self.id = id }
}

/// Parsed `<radialGradient>` definition.
public struct SVGRadialGradientDef {
    public var id: String
    public var cx: Double = 0.5
    public var cy: Double = 0.5
    public var r: Double = 0.5
    public var fx: Double? = nil
    public var fy: Double? = nil
    public var gradientUnits: SVGGradientUnits = .objectBoundingBox
    public var gradientTransform: CGAffineTransform = .identity
    public var stops: [SVGGradientStop] = []
    public var href: String? = nil
    public init(id: String) { self.id = id }
}

/// Gradient coordinate space.
public enum SVGGradientUnits: Sendable, Equatable { case objectBoundingBox, userSpaceOnUse }

// MARK: - Filter Definitions

/// Parsed `<filter>` definition.
public struct SVGFilterDef {
    public var id: String
    public var primitives: [SVGFilterPrimitive] = []
    public init(id: String, primitives: [SVGFilterPrimitive] = []) { self.id = id; self.primitives = primitives }
}

/// Supported SVG filter primitives.
public enum SVGFilterPrimitive {
    case gaussianBlur(stdDeviation: Double)
    case dropShadow(dx: Double, dy: Double, stdDeviation: Double, color: Color)
}

// MARK: - Mask Definition

/// Parsed `<mask>` definition.
public struct SVGMaskDef {
    public let id: String
    public let children: [SVGElement]
    public init(id: String, children: [SVGElement]) { self.id = id; self.children = children }
}

// MARK: - SVG Override

/// Per-element style override applied at render time.
@Init @Copy
public struct SVGOverride {
    public var fill: Color? = nil
    public var stroke: Color? = nil
    public var strokeWidth: Double? = nil
    public var opacity: Double? = nil
    public var fillOpacity: Double? = nil
    public var strokeOpacity: Double? = nil
    public var dashArray: [CGFloat]? = nil
    public var visibility: SVGVisibility? = nil
    public var isHidden: Bool = false
}

// MARK: - SVG Painter

/// Paints an SVGDocument directly onto a Canvas.
@Init
public struct SVGPainter {
    public var document: SVGDocument
    public var overrides: [String: SVGOverride] = [:]
    public var globalColor: Color? = nil
    public var globalStrokeWidth: Double? = nil

    public func paint(on canvas: Canvas) {
        for element in document.elements {
            paintElement(element, on: canvas)
        }
    }

    // MARK: - Element dispatch

    private func paintElement(_ element: SVGElement, on canvas: Canvas) {
        switch element {
        case .path(let data):
            let path = SVGPathDataParser.parse(data.d)
            paintShape(path, attributes: data.attributes, id: data.id, on: canvas)

        case .rect(let data):
            let r = Rect(x: data.x, y: data.y, width: data.width, height: data.height)
            let path = data.rx > 0 || data.ry > 0
                ? RoundedModifiedShape(base: RectShape().erased, radii: [data.rx > 0 ? data.rx : data.ry], smooth: 0).path(in: r)
                : RectShape().path(in: r)
            paintShape(path, attributes: data.attributes, id: data.id, on: canvas)

        case .circle(let data):
            let r = Rect.fromCircle(center: Point(data.cx, data.cy), radius: data.r)
            paintShape(EllipseShape().path(in: r), attributes: data.attributes, id: data.id, on: canvas)

        case .ellipse(let data):
            let r = Rect(x: data.cx - data.rx, y: data.cy - data.ry, width: data.rx * 2, height: data.ry * 2)
            paintShape(EllipseShape().path(in: r), attributes: data.attributes, id: data.id, on: canvas)

        case .line(let data):
            var attrs = data.attributes; attrs.fill = .none
            if case .none = attrs.stroke { attrs.stroke = .color(.black) }
            let path = Path.line(from: Point(Double(data.x1), Double(data.y1)), to: Point(Double(data.x2), Double(data.y2)))
            paintShape(path, attributes: attrs, id: data.id, on: canvas)

        case .polygon(let data):
            guard !data.points.isEmpty else { return }
            paintShape(Path.polygon(data.points), attributes: data.attributes, id: data.id, on: canvas)

        case .polyline(let data):
            guard !data.points.isEmpty else { return }
            paintShape(Path.polyline(data.points), attributes: data.attributes, id: data.id, on: canvas)

        case .group(let data):
            paintGroup(data, on: canvas)

        case .use(let data):
            paintUse(data, on: canvas)

        case .image(let data):
            paintImage(data, on: canvas)

        case .text(let data):
            paintText(data, on: canvas)
        }
    }

    // MARK: - Shape rendering

    private func paintShape(_ path: Path, attributes attrs: SVGPaintAttributes, id: String, on canvas: Canvas) {
        let ov = overrides[id]
        if ov?.isHidden == true { return }
        if (ov?.visibility ?? attrs.visibility) != .visible || attrs.display == .none { return }

        let opacity = ov?.opacity ?? attrs.opacity

        canvas.save()
        if attrs.transform != .identity { canvas.transform(Transform2D(attrs.transform)) }
        if opacity < 1 { canvas.setAlpha(opacity) }

        // Clip path
        if let clipID = attrs.clipPathID, let clipElements = document.defs.clipPaths[clipID] {
            let clipPath = buildClipPath(from: clipElements)
            canvas.clip(clipPath)
        }

        // Filter
        applyFilter(attrs, on: canvas)

        // Fill
        let fillPaint = ov?.fill.map { SVGPaint.color($0) } ?? attrs.fill
        let fillOpacity = ov?.fillOpacity ?? attrs.fillOpacity
        paintFill(fillPaint, opacity: fillOpacity, path: path, rule: attrs.fillRule, on: canvas)

        // Stroke
        let strokePaint = ov?.stroke.map { SVGPaint.color($0) } ?? attrs.stroke
        let strokeOpacity = ov?.strokeOpacity ?? attrs.strokeOpacity
        let strokeWidth = ov?.strokeWidth.map { CGFloat($0) } ?? globalStrokeWidth.map { CGFloat($0) } ?? attrs.strokeWidth
        let dashArray = ov?.dashArray ?? attrs.strokeDashArray
        paintStroke(strokePaint, opacity: strokeOpacity, path: path, width: strokeWidth,
                    cap: attrs.strokeLineCap, join: attrs.strokeLineJoin, miterLimit: attrs.strokeMiterLimit,
                    dashArray: dashArray, dashOffset: attrs.strokeDashOffset, on: canvas)

        canvas.restore()
    }

    // MARK: - Fill

    private func paintFill(_ paint: SVGPaint, opacity: Double, path: Path, rule: FillRule, on canvas: Canvas) {
        switch paint {
        case .none:
            return
        case .color(let c):
            let resolved = globalColor.map { _ in globalColor! } ?? c
            let color = opacity < 1 ? resolved.withAlpha(resolved.alpha * opacity) : resolved
            canvas.fillColor(path, color, rule: rule)
        case .currentColor:
            let c = globalColor ?? .black
            let color = opacity < 1 ? c.withAlpha(c.alpha * opacity) : c
            canvas.fillColor(path, color, rule: rule)
        case .url(let id):
            paintGradientFill(id: id, opacity: opacity, path: path, on: canvas)
        }
    }

    private func paintGradientFill(id: String, opacity: Double, path: Path, on canvas: Canvas) {
        let bounds = path.boundingBox
        canvas.save()
        canvas.clip(path)
        if opacity < 1 { canvas.setAlpha(opacity) }

        if let linear = resolveLinearGradient(id) {
            let stops = resolveStops(linear.stops, gradientID: id)
            let forgeStops = stops.map { GradientStop($0.color.withAlpha($0.color.alpha * $0.opacity), at: $0.offset) }
            if linear.gradientUnits == .objectBoundingBox {
                canvas.drawLinearGradient(stops: forgeStops, start: Vec2(linear.x1, linear.y1), end: Vec2(linear.x2, linear.y2), in: bounds)
            } else {
                canvas.drawLinearGradient(stops: forgeStops,
                    start: Vec2((linear.x1 - bounds.x) / bounds.width, (linear.y1 - bounds.y) / bounds.height),
                    end: Vec2((linear.x2 - bounds.x) / bounds.width, (linear.y2 - bounds.y) / bounds.height), in: bounds)
            }
        } else if let radial = resolveRadialGradient(id) {
            let stops = resolveStops(radial.stops, gradientID: id)
            let forgeStops = stops.map { GradientStop($0.color.withAlpha($0.color.alpha * $0.opacity), at: $0.offset) }
            if radial.gradientUnits == .objectBoundingBox {
                canvas.drawRadialGradient(stops: forgeStops, center: Vec2(radial.cx, radial.cy), radius: radial.r, in: bounds)
            } else {
                canvas.drawRadialGradient(stops: forgeStops,
                    center: Vec2((radial.cx - bounds.x) / bounds.width, (radial.cy - bounds.y) / bounds.height),
                    radius: radial.r / max(bounds.width, bounds.height), in: bounds)
            }
        }

        canvas.restore()
    }

    // MARK: - Stroke

    private func paintStroke(_ paint: SVGPaint, opacity: Double, path: Path,
                             width: CGFloat, cap: CGLineCap, join: CGLineJoin, miterLimit: CGFloat,
                             dashArray: [CGFloat], dashOffset: CGFloat, on canvas: Canvas) {
        if case .none = paint { return }

        var strokePath = path
        if !dashArray.isEmpty {
            strokePath = strokePath.dashed(phase: Double(dashOffset), lengths: dashArray.map { Double($0) })
        }
        let stroked = strokePath.stroked(width: Double(width), cap: StrokeCap(cap), join: StrokeJoin(join), miterLimit: Double(miterLimit))

        switch paint {
        case .color(let c):
            let color = opacity < 1 ? c.withAlpha(c.alpha * opacity) : c
            canvas.draw(stroked, with: .color(color))
        case .currentColor:
            let c = globalColor ?? .black
            let color = opacity < 1 ? c.withAlpha(c.alpha * opacity) : c
            canvas.draw(stroked, with: .color(color))
        case .url(let id):
            canvas.save()
            canvas.clip(stroked)
            if opacity < 1 { canvas.setAlpha(opacity) }
            let bounds = stroked.boundingBox
            if let linear = resolveLinearGradient(id) {
                let stops = resolveStops(linear.stops, gradientID: id)
                let forgeStops = stops.map { GradientStop($0.color.withAlpha($0.color.alpha * $0.opacity), at: $0.offset) }
                canvas.drawLinearGradient(stops: forgeStops, start: Vec2(linear.x1, linear.y1), end: Vec2(linear.x2, linear.y2), in: bounds)
            } else if let radial = resolveRadialGradient(id) {
                let stops = resolveStops(radial.stops, gradientID: id)
                let forgeStops = stops.map { GradientStop($0.color.withAlpha($0.color.alpha * $0.opacity), at: $0.offset) }
                canvas.drawRadialGradient(stops: forgeStops, center: Vec2(radial.cx, radial.cy), radius: radial.r, in: bounds)
            }
            canvas.restore()
        case .none:
            return
        }
    }

    // MARK: - Group

    private func paintGroup(_ data: SVGGroupData, on canvas: Canvas) {
        let ov = overrides[data.id]
        if ov?.isHidden == true { return }
        if data.attributes.visibility != .visible || data.attributes.display == .none { return }

        let opacity = ov?.opacity ?? data.attributes.opacity

        canvas.save()
        if data.attributes.transform != .identity { canvas.transform(Transform2D(data.attributes.transform)) }
        if opacity < 1 { canvas.setAlpha(opacity) }

        if let clipID = data.attributes.clipPathID, let clipElements = document.defs.clipPaths[clipID] {
            canvas.clip(buildClipPath(from: clipElements))
        }
        applyFilter(data.attributes, on: canvas)

        for child in data.children { paintElement(child, on: canvas) }
        canvas.restore()
    }

    // MARK: - Use

    private func paintUse(_ data: SVGUseData, on canvas: Canvas) {
        guard let referenced = document.defs.reusableElements[data.href] else { return }
        canvas.save()
        canvas.translate(Double(data.x), Double(data.y))
        if data.attributes.transform != .identity { canvas.transform(Transform2D(data.attributes.transform)) }
        if data.attributes.opacity < 1 { canvas.setAlpha(data.attributes.opacity) }
        for element in referenced { paintElement(element, on: canvas) }
        canvas.restore()
    }

    // MARK: - Image

    private func paintImage(_ data: SVGImageData, on canvas: Canvas) {
        if data.attributes.visibility != .visible || data.attributes.display == .none { return }
        canvas.save()
        if data.attributes.transform != .identity { canvas.transform(Transform2D(data.attributes.transform)) }
        if data.attributes.opacity < 1 { canvas.setAlpha(data.attributes.opacity) }

        let bounds = Rect(x: data.x, y: data.y, width: data.width, height: data.height)

        // Base64 data URIs — platform-specific image decoding
        #if canImport(UIKit)
        if data.href.hasPrefix("data:") {
            if let commaIndex = data.href.firstIndex(of: ",") {
                let base64String = String(data.href[data.href.index(after: commaIndex)...])
                if let imageData = Data(base64Encoded: base64String),
                   let uiImage = UIImage(data: imageData) {
                    canvas.drawImage(ImageSource(uiImage), fit: .fill, in: bounds)
                }
            }
        }
        #endif

        canvas.restore()
    }

    // MARK: - Text

    private func paintText(_ data: SVGTextData, on canvas: Canvas) {
        if data.attributes.visibility != .visible || data.attributes.display == .none { return }

        canvas.save()
        if data.attributes.transform != .identity { canvas.transform(Transform2D(data.attributes.transform)) }
        if data.attributes.opacity < 1 { canvas.setAlpha(data.attributes.opacity) }

        #if canImport(CoreText)
        var cursorX = Double(data.x)
        let cursorY = Double(data.y)

        for span in data.spans {
            let spanX = span.x.map { Double($0) } ?? cursorX + Double(span.dx)
            let spanY = span.y.map { Double($0) } ?? cursorY + Double(span.dy)
            let size = span.fontSize ?? data.fontSize
            let weight = span.fontWeight ?? data.fontWeight

            let ctWeight = ctFontWeight(weight)
            let font = CTFontCreateWithName((data.fontFamily.isEmpty ? "Helvetica" : data.fontFamily) as CFString, size, nil)
            let weighted = CTFontCreateCopyWithSymbolicTraits(font, size, nil,
                ctWeight > 0.2 ? .boldTrait : [], .boldTrait) ?? font

            let attrString = CFAttributedStringCreate(nil, span.text as CFString,
                [kCTFontAttributeName: weighted] as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attrString)
            let glyphRuns = CTLineGetGlyphRuns(line) as! [CTRun]

            var textPath = Path()
            for run in glyphRuns {
                let glyphCount = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                CTRunGetGlyphs(run, CFRange(location: 0, length: glyphCount), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: glyphCount), &positions)

                for g in 0..<glyphCount {
                    if let glyphPath = CTFontCreatePathForGlyph(weighted, glyphs[g], nil) {
                        var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: positions[g].x, ty: 0)
                        if let flipped = glyphPath.copy(using: &t) {
                            textPath.addPath(Path(cgPath: flipped))
                        }
                    }
                }
            }

            // Anchor alignment
            let textBounds = textPath.boundingBox
            var offsetX = spanX
            switch data.textAnchor {
            case .middle: offsetX -= textBounds.width / 2
            case .end: offsetX -= textBounds.width
            case .start: break
            }

            canvas.save()
            canvas.translate(offsetX, spanY)

            let attrs = span.attributes ?? data.attributes
            paintFill(attrs.fill, opacity: attrs.fillOpacity, path: textPath, rule: attrs.fillRule, on: canvas)
            if case .none = attrs.stroke {} else {
                paintStroke(attrs.stroke, opacity: attrs.strokeOpacity, path: textPath,
                            width: attrs.strokeWidth, cap: attrs.strokeLineCap, join: attrs.strokeLineJoin,
                            miterLimit: attrs.strokeMiterLimit, dashArray: attrs.strokeDashArray,
                            dashOffset: attrs.strokeDashOffset, on: canvas)
            }
            canvas.restore()

            cursorX = spanX + textBounds.width
        }
        #endif

        canvas.restore()
    }

    #if canImport(CoreText)
    private func ctFontWeight(_ weight: String) -> CGFloat {
        switch weight.lowercased() {
        case "bold", "700": return 0.4
        case "bolder", "800", "900": return 0.6
        case "lighter", "100", "200": return -0.6
        case "300": return -0.4
        case "500": return 0.1
        case "600": return 0.3
        default: return 0
        }
    }
    #endif

    // MARK: - Helpers

    private func applyFilter(_ attrs: SVGPaintAttributes, on canvas: Canvas) {
        guard let filterID = attrs.filterID, let filterDef = document.defs.filters[filterID] else { return }
        for primitive in filterDef.primitives {
            switch primitive {
            case .gaussianBlur(let std):
                canvas.filter(.blur(radius: std))
            case .dropShadow(let dx, let dy, let std, let color):
                canvas.filter(.shadow(color: color, offset: Vec2(dx, dy), blur: std))
            }
        }
    }

    private func buildClipPath(from elements: [SVGElement]) -> Path {
        var combined = Path()
        for element in elements {
            switch element {
            case .path(let d): combined.addPath(SVGPathDataParser.parse(d.d))
            case .rect(let d):
                let r = Rect(x: d.x, y: d.y, width: d.width, height: d.height)
                combined.addPath(RectShape().path(in: r))
            case .circle(let d):
                combined.addPath(EllipseShape().path(in: Rect.fromCircle(center: Point(d.cx, d.cy), radius: d.r)))
            case .ellipse(let d):
                combined.addPath(EllipseShape().path(in: Rect(x: d.cx - d.rx, y: d.cy - d.ry, width: d.rx * 2, height: d.ry * 2)))
            default: break
            }
        }
        return combined
    }

    private func resolveLinearGradient(_ id: String) -> SVGLinearGradientDef? {
        document.defs.linearGradients[id]
    }

    private func resolveRadialGradient(_ id: String) -> SVGRadialGradientDef? {
        document.defs.radialGradients[id]
    }

    private func resolveStops(_ stops: [SVGGradientStop], gradientID: String) -> [SVGGradientStop] {
        if !stops.isEmpty { return stops }
        // Follow href chain
        if let linear = document.defs.linearGradients[gradientID], let href = linear.href {
            if let parent = document.defs.linearGradients[href] { return resolveStops(parent.stops, gradientID: href) }
            if let parent = document.defs.radialGradients[href] { return resolveStops(parent.stops, gradientID: href) }
        }
        if let radial = document.defs.radialGradients[gradientID], let href = radial.href {
            if let parent = document.defs.linearGradients[href] { return resolveStops(parent.stops, gradientID: href) }
            if let parent = document.defs.radialGradients[href] { return resolveStops(parent.stops, gradientID: href) }
        }
        return []
    }
}

// MARK: - SVG Parser

/// Parses SVG XML data into an SVGDocument.
public final class SVGParser: NSObject, XMLParserDelegate {
    private var viewBox: CGRect = .zero
    private var rootWidth: CGFloat?
    private var rootHeight: CGFloat?
    private var rootPaintAttributes: SVGPaintAttributes = .defaults
    private var elementStack: [SVGGroupBuilder] = []
    private var rootElements: [SVGElement] = []
    private var elementCounters: [String: Int] = [:]
    private var defs = SVGDefs()

    // Defs parsing state
    private var inDefs = false
    private var defsElementStack: [SVGGroupBuilder] = []
    private var currentDefsID: String?

    // Gradient parsing state
    private var currentLinearGradient: SVGLinearGradientDef?
    private var currentRadialGradient: SVGRadialGradientDef?
    private var currentGradientStops: [SVGGradientStop] = []

    // Filter parsing state
    private var currentFilter: SVGFilterDef?

    // Mask parsing state
    private var inMask = false
    private var currentMaskID: String?
    private var maskElements: [SVGElement] = []

    // ClipPath parsing state
    private var inClipPath = false
    private var currentClipPathID: String?
    private var clipPathElements: [SVGElement] = []

    // Text parsing state
    private var inText = false
    private var textBuilder: SVGTextBuilder?
    private var currentSpanAttrs: SVGPaintAttributes?

    // Style parsing state
    private var inStyleElement = false
    private var styleText = ""
    private var styleSheet: [String: [String: String]] = [:]

    // Character accumulation
    private var characterBuffer = ""

    public func parse(_ string: String) -> SVGDocument? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data)
    }

    public func parse(_ data: Data) -> SVGDocument? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }

        let resolvedViewBox: CGRect
        if viewBox != .zero {
            resolvedViewBox = viewBox
        } else if let w = rootWidth, let h = rootHeight {
            resolvedViewBox = CGRect(x: 0, y: 0, width: w, height: h)
        } else {
            resolvedViewBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        return SVGDocument(viewBox: resolvedViewBox, elements: rootElements, defs: defs)
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        characterBuffer = ""

        switch elementName {
        case "svg":
            parseSVGRoot(attributes)

        case "defs":
            inDefs = true

        case "style":
            inStyleElement = true
            styleText = ""

        case "linearGradient":
            parseLinearGradientStart(attributes)

        case "radialGradient":
            parseRadialGradientStart(attributes)

        case "stop":
            parseGradientStop(attributes)

        case "clipPath":
            inClipPath = true
            currentClipPathID = attributes["id"]
            clipPathElements = []

        case "filter":
            currentFilter = SVGFilterDef(id: attributes["id"] ?? "")

        case "feGaussianBlur":
            if let std = attributes["stdDeviation"].flatMap({ Double($0) }) {
                currentFilter?.primitives.append(.gaussianBlur(stdDeviation: std))
            }

        case "feDropShadow":
            let dx = attributes["dx"].flatMap { Double($0) } ?? 0
            let dy = attributes["dy"].flatMap { Double($0) } ?? 0
            let std = attributes["stdDeviation"].flatMap { Double($0) } ?? 0
            let color = attributes["flood-color"].flatMap { parseColor($0) } ?? .black
            let opacity = attributes["flood-opacity"].flatMap { Double($0) } ?? 1
            currentFilter?.primitives.append(.dropShadow(dx: dx, dy: dy, stdDeviation: std, color: color.withAlpha(opacity)))

        case "mask":
            inMask = true
            currentMaskID = attributes["id"]
            maskElements = []

        case "use":
            parseUse(attributes)

        case "image":
            parseImage(attributes)

        case "text":
            parseTextStart(attributes)

        case "tspan":
            parseTSpanStart(attributes)

        case "g":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Group")
            let builder = SVGGroupBuilder(id: id, attributes: attrs)
            if inDefs { defsElementStack.append(builder) }
            else if inClipPath || inMask { /* handled via appendElement */ }
            else { elementStack.append(builder) }

        default:
            parseShapeElement(elementName, attributes: attributes)
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "defs":
            inDefs = false

        case "style":
            inStyleElement = false
            parseStyleSheet(styleText)

        case "linearGradient":
            if var gradient = currentLinearGradient {
                gradient.stops = currentGradientStops
                defs.linearGradients[gradient.id] = gradient
            }
            currentLinearGradient = nil
            currentGradientStops = []

        case "radialGradient":
            if var gradient = currentRadialGradient {
                gradient.stops = currentGradientStops
                defs.radialGradients[gradient.id] = gradient
            }
            currentRadialGradient = nil
            currentGradientStops = []

        case "clipPath":
            if let id = currentClipPathID {
                defs.clipPaths[id] = clipPathElements
            }
            inClipPath = false
            currentClipPathID = nil

        case "filter":
            if let filter = currentFilter {
                defs.filters[filter.id] = filter
            }
            currentFilter = nil

        case "mask":
            if let id = currentMaskID {
                defs.masks[id] = SVGMaskDef(id: id, children: maskElements)
            }
            inMask = false
            currentMaskID = nil

        case "text":
            finalizeText()

        case "tspan":
            finalizeTSpan()

        case "g":
            if inDefs {
                if let builder = defsElementStack.popLast() {
                    let group = SVGGroupData(id: builder.id, attributes: builder.attributes, children: builder.children)
                    if let id = builder.attributes.clipPathID ?? Optional(builder.id) {
                        defs.reusableElements[id] = [.group(group)]
                    }
                }
            } else if let builder = elementStack.popLast() {
                appendElement(.group(SVGGroupData(id: builder.id, attributes: builder.attributes, children: builder.children)))
            }

        default:
            break
        }

        if inStyleElement {
            styleText += characterBuffer
        }
        characterBuffer = ""
    }

    // MARK: - Shape Elements

    private func parseShapeElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case "path":
            if let d = attributes["d"] {
                let attrs = parsePaintAttributes(attributes)
                let id = resolveID(attributes["id"], elementName: "Path")
                appendElement(.path(SVGPathData(id: id, d: d, attributes: attrs)))
            }
        case "rect":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Rect")
            appendElement(.rect(SVGRectData(id: id, x: cgFloat(attributes["x"]), y: cgFloat(attributes["y"]),
                width: cgFloat(attributes["width"]), height: cgFloat(attributes["height"]),
                rx: cgFloat(attributes["rx"]), ry: cgFloat(attributes["ry"]), attributes: attrs)))
        case "circle":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Circle")
            appendElement(.circle(SVGCircleData(id: id, cx: cgFloat(attributes["cx"]), cy: cgFloat(attributes["cy"]),
                r: cgFloat(attributes["r"]), attributes: attrs)))
        case "ellipse":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Ellipse")
            appendElement(.ellipse(SVGEllipseData(id: id, cx: cgFloat(attributes["cx"]), cy: cgFloat(attributes["cy"]),
                rx: cgFloat(attributes["rx"]), ry: cgFloat(attributes["ry"]), attributes: attrs)))
        case "line":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Line")
            appendElement(.line(SVGLineData(id: id, x1: cgFloat(attributes["x1"]), y1: cgFloat(attributes["y1"]),
                x2: cgFloat(attributes["x2"]), y2: cgFloat(attributes["y2"]), attributes: attrs)))
        case "polygon":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Polygon")
            appendElement(.polygon(SVGPolygonData(id: id, points: parsePoints(attributes["points"] ?? ""), attributes: attrs)))
        case "polyline":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Polyline")
            appendElement(.polyline(SVGPolygonData(id: id, points: parsePoints(attributes["points"] ?? ""), attributes: attrs)))
        default:
            break
        }
    }

    // MARK: - Gradient Parsing

    private func parseLinearGradientStart(_ attributes: [String: String]) {
        let id = attributes["id"] ?? ""
        var gradient = SVGLinearGradientDef(id: id)
        if let v = attributes["x1"] { gradient.x1 = parseGradientCoord(v) }
        if let v = attributes["y1"] { gradient.y1 = parseGradientCoord(v) }
        if let v = attributes["x2"] { gradient.x2 = parseGradientCoord(v) }
        if let v = attributes["y2"] { gradient.y2 = parseGradientCoord(v) }
        if attributes["gradientUnits"] == "userSpaceOnUse" { gradient.gradientUnits = .userSpaceOnUse }
        if let t = attributes["gradientTransform"] { gradient.gradientTransform = parseTransform(t) }
        gradient.href = parseHref(attributes)
        currentLinearGradient = gradient
        currentGradientStops = []
    }

    private func parseRadialGradientStart(_ attributes: [String: String]) {
        let id = attributes["id"] ?? ""
        var gradient = SVGRadialGradientDef(id: id)
        if let v = attributes["cx"] { gradient.cx = parseGradientCoord(v) }
        if let v = attributes["cy"] { gradient.cy = parseGradientCoord(v) }
        if let v = attributes["r"] { gradient.r = parseGradientCoord(v) }
        if let v = attributes["fx"] { gradient.fx = parseGradientCoord(v) }
        if let v = attributes["fy"] { gradient.fy = parseGradientCoord(v) }
        if attributes["gradientUnits"] == "userSpaceOnUse" { gradient.gradientUnits = .userSpaceOnUse }
        if let t = attributes["gradientTransform"] { gradient.gradientTransform = parseTransform(t) }
        gradient.href = parseHref(attributes)
        currentRadialGradient = gradient
        currentGradientStops = []
    }

    private func parseGradientStop(_ attributes: [String: String]) {
        var offset: Double = 0
        if let v = attributes["offset"] {
            if v.hasSuffix("%") { offset = (Double(v.dropLast()) ?? 0) / 100 }
            else { offset = Double(v) ?? 0 }
        }
        let color = attributes["stop-color"].flatMap { parseColor($0) } ?? .black
        let opacity = attributes["stop-opacity"].flatMap { Double($0) } ?? 1
        currentGradientStops.append(SVGGradientStop(offset: offset, color: color, opacity: opacity))
    }

    private func parseGradientCoord(_ value: String) -> Double {
        if value.hasSuffix("%") { return (Double(value.dropLast()) ?? 0) / 100 }
        return Double(value) ?? 0
    }

    private func parseHref(_ attributes: [String: String]) -> String? {
        let raw = attributes["href"] ?? attributes["xlink:href"]
        return raw?.hasPrefix("#") == true ? String(raw!.dropFirst()) : raw
    }

    // MARK: - Use/Image Parsing

    private func parseUse(_ attributes: [String: String]) {
        let id = resolveID(attributes["id"], elementName: "Use")
        let href = parseHref(attributes) ?? ""
        let x = cgFloat(attributes["x"])
        let y = cgFloat(attributes["y"])
        let attrs = parsePaintAttributes(attributes)
        appendElement(.use(SVGUseData(id: id, href: href, x: x, y: y, attributes: attrs)))
    }

    private func parseImage(_ attributes: [String: String]) {
        let id = resolveID(attributes["id"], elementName: "Image")
        let href = attributes["href"] ?? attributes["xlink:href"] ?? ""
        let attrs = parsePaintAttributes(attributes)
        appendElement(.image(SVGImageData(id: id, x: cgFloat(attributes["x"]), y: cgFloat(attributes["y"]),
            width: cgFloat(attributes["width"]), height: cgFloat(attributes["height"]),
            href: href, attributes: attrs)))
    }

    // MARK: - Text Parsing

    private func parseTextStart(_ attributes: [String: String]) {
        inText = true
        let attrs = parsePaintAttributes(attributes)
        textBuilder = SVGTextBuilder(
            id: resolveID(attributes["id"], elementName: "Text"),
            x: cgFloat(attributes["x"]), y: cgFloat(attributes["y"]),
            fontSize: cgFloat(attributes["font-size"]),
            fontFamily: attributes["font-family"] ?? "",
            fontWeight: attributes["font-weight"] ?? "normal",
            textAnchor: parseTextAnchor(attributes["text-anchor"]),
            attributes: attrs)
    }

    private func parseTSpanStart(_ attributes: [String: String]) {
        // Flush any accumulated text before this tspan
        let buffered = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !buffered.isEmpty, let tb = textBuilder {
            tb.spans.append(SVGTextSpan(text: buffered, x: nil, y: nil, dx: 0, dy: 0,
                fontSize: nil, fontWeight: nil, attributes: nil))
        }
        characterBuffer = ""
        currentSpanAttrs = parsePaintAttributes(attributes)
    }

    private func finalizeTSpan() {
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        characterBuffer = ""
        guard !text.isEmpty, let tb = textBuilder else { return }
        tb.spans.append(SVGTextSpan(text: text, x: nil, y: nil, dx: 0, dy: 0,
            fontSize: nil, fontWeight: nil, attributes: currentSpanAttrs))
        currentSpanAttrs = nil
    }

    private func finalizeText() {
        // Flush any remaining text
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let tb = textBuilder {
            tb.spans.append(SVGTextSpan(text: text, x: nil, y: nil, dx: 0, dy: 0,
                fontSize: nil, fontWeight: nil, attributes: nil))
        }
        characterBuffer = ""

        if let tb = textBuilder {
            let fontSize = tb.fontSize > 0 ? tb.fontSize : 16
            appendElement(.text(SVGTextData(id: tb.id, x: tb.x, y: tb.y,
                fontSize: fontSize, fontFamily: tb.fontFamily, fontWeight: tb.fontWeight,
                textAnchor: tb.textAnchor, attributes: tb.attributes, spans: tb.spans)))
        }
        textBuilder = nil
        inText = false
    }

    private func parseTextAnchor(_ value: String?) -> SVGTextAnchor {
        switch value { case "middle": .middle; case "end": .end; default: .start }
    }

    // MARK: - CSS Style Parsing

    private func parseStyleSheet(_ css: String) {
        let cleaned = css.replacingOccurrences(of: "\n", with: " ")
        guard let regex = try? NSRegularExpression(pattern: #"\.([a-zA-Z0-9_-]+)\s*\{([^}]+)\}"#) else { return }
        let nsCSS = cleaned as NSString
        for match in regex.matches(in: cleaned, range: NSRange(location: 0, length: nsCSS.length)) {
            let className = nsCSS.substring(with: match.range(at: 1))
            let body = nsCSS.substring(with: match.range(at: 2))
            styleSheet[className] = parseInlineCSS(body)
        }
    }

    private func parseInlineCSS(_ style: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in style.split(separator: ";") {
            let kv = pair.split(separator: ":", maxSplits: 1)
            guard kv.count == 2 else { continue }
            result[kv[0].trimmingCharacters(in: .whitespaces)] = kv[1].trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    // MARK: - Element Management

    private func appendElement(_ element: SVGElement) {
        if inClipPath { clipPathElements.append(element); return }
        if inMask { maskElements.append(element); return }
        if inDefs {
            if let last = defsElementStack.last {
                last.children.append(element)
            } else {
                // Top-level defs element — store by ID
                let id: String
                switch element {
                case .path(let d): id = d.id
                case .rect(let d): id = d.id
                case .circle(let d): id = d.id
                case .ellipse(let d): id = d.id
                case .line(let d): id = d.id
                case .polygon(let d): id = d.id
                case .polyline(let d): id = d.id
                case .group(let d): id = d.id
                case .use(let d): id = d.id
                case .image(let d): id = d.id
                case .text(let d): id = d.id
                }
                defs.reusableElements[id] = [element]
            }
            return
        }
        if elementStack.isEmpty { rootElements.append(element) }
        else { elementStack[elementStack.count - 1].children.append(element) }
    }

    // MARK: - Paint Attributes

    private func parsePaintAttributes(_ attributes: [String: String]) -> SVGPaintAttributes {
        let inherited = elementStack.last?.attributes ?? rootPaintAttributes
        var result = inherited
        result.transform = .identity

        // Apply class-based CSS first (lower priority)
        if let className = attributes["class"] {
            for cls in className.split(separator: " ") {
                if let cssProps = styleSheet[String(cls)] {
                    applyCSS(cssProps, to: &result)
                }
            }
        }

        // Apply presentation attributes (medium priority)
        applyPresentationAttributes(attributes, to: &result)

        // Apply inline style (highest priority)
        if let style = attributes["style"] {
            let cssProps = parseInlineCSS(style)
            applyCSS(cssProps, to: &result)
        }

        return result
    }

    private func applyPresentationAttributes(_ attributes: [String: String], to result: inout SVGPaintAttributes) {
        if let fill = attributes["fill"] { result.fill = parsePaint(fill) }
        if let stroke = attributes["stroke"] { result.stroke = parsePaint(stroke) }
        if let v = attributes["stroke-width"], let val = Double(v) { result.strokeWidth = CGFloat(val) }
        if let cap = attributes["stroke-linecap"] { result.strokeLineCap = parseLineCap(cap) }
        if let join = attributes["stroke-linejoin"] { result.strokeLineJoin = parseLineJoin(join) }
        if let v = attributes["stroke-miterlimit"], let val = Double(v) { result.strokeMiterLimit = CGFloat(val) }
        if let v = attributes["stroke-dasharray"] { result.strokeDashArray = parseDashArray(v) }
        if let v = attributes["stroke-dashoffset"], let val = Double(v) { result.strokeDashOffset = CGFloat(val) }
        if let v = attributes["stroke-opacity"], let val = Double(v) { result.strokeOpacity = val }
        if let v = attributes["opacity"], let val = Double(v) { result.opacity = val }
        if let v = attributes["fill-opacity"], let val = Double(v) { result.fillOpacity = val }
        if let v = attributes["fill-rule"] { result.fillRule = v == "evenodd" ? .evenOdd : .winding }
        if let v = attributes["visibility"] {
            result.visibility = v == "hidden" ? .hidden : v == "collapse" ? .collapse : .visible
        }
        if let v = attributes["display"] { result.display = v == "none" ? .none : .inline }
        if let v = attributes["clip-path"] { result.clipPathID = parseURLID(v) }
        if let v = attributes["filter"] { result.filterID = parseURLID(v) }
        if let v = attributes["mask"] { result.maskID = parseURLID(v) }
        if let transform = attributes["transform"] { result.transform = parseTransform(transform) }
    }

    private func applyCSS(_ props: [String: String], to result: inout SVGPaintAttributes) {
        // Reuse the same parsing — CSS properties have the same names as presentation attributes
        applyPresentationAttributes(props, to: &result)
    }

    private func parseDashArray(_ value: String) -> [CGFloat] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed == "none" { return [] }
        return trimmed.split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .map { CGFloat($0) }
    }

    private func parseURLID(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("url(#") && trimmed.hasSuffix(")") {
            return String(trimmed.dropFirst(5).dropLast())
        }
        return nil
    }

    // MARK: - Root

    private func parseSVGRoot(_ attributes: [String: String]) {
        if let vb = attributes["viewBox"] {
            let parts = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if parts.count == 4 { viewBox = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3]) }
        }
        rootWidth = attributes["width"].flatMap { parseDimension($0) }
        rootHeight = attributes["height"].flatMap { parseDimension($0) }
        rootPaintAttributes = parsePaintAttributes(attributes)
    }

    // MARK: - Value Parsing

    private func parseDimension(_ value: String) -> CGFloat? {
        Double(value.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "pt", with: "").trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
    }

    private func resolveID(_ explicit: String?, elementName: String) -> String {
        if let explicit { return explicit }
        let count = (elementCounters[elementName] ?? 0) + 1
        elementCounters[elementName] = count
        return "\(elementName) \(count)"
    }

    private func parsePaint(_ value: String) -> SVGPaint {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed == "none" { return .none }
        if trimmed == "currentColor" { return .currentColor }
        if trimmed.hasPrefix("url(#") {
            if let id = parseURLID(trimmed) { return .url(id) }
        }
        if let color = parseColor(trimmed) { return .color(color) }
        return .color(.black)
    }

    private func parseColor(_ value: String) -> Color? {
        if value.hasPrefix("#") { return hexColor(value) }
        if value.hasPrefix("rgb") { return rgbColor(value) }
        return namedColor(value)
    }

    private func hexColor(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("#") { str.removeFirst() }
        if str.count == 3 { str = str.map { "\($0)\($0)" }.joined() }
        guard str.count == 6, let val = UInt64(str, radix: 16) else { return nil }
        return Color(CGFloat((val >> 16) & 0xFF) / 255, CGFloat((val >> 8) & 0xFF) / 255, CGFloat(val & 0xFF) / 255)
    }

    private func rgbColor(_ value: String) -> Color? {
        let inner = value.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }
        let parts = inner.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 3 else { return nil }
        return Color(CGFloat(parts[0]) / 255, CGFloat(parts[1]) / 255, CGFloat(parts[2]) / 255)
    }

    private func namedColor(_ value: String) -> Color? {
        switch value.lowercased() {
        case "black": return .black; case "white": return .white
        case "red": return .red; case "green": return .green; case "blue": return .blue
        case "yellow": return Color(1, 1, 0); case "cyan": return Color(0, 1, 1)
        case "magenta": return Color(1, 0, 1); case "orange": return Color(1, 0.647, 0)
        case "gray", "grey": return Color(0.5, 0.5, 0.5)
        case "silver": return Color(0.753, 0.753, 0.753)
        case "maroon": return Color(0.5, 0, 0)
        case "purple": return Color(0.5, 0, 0.5)
        case "navy": return Color(0, 0, 0.5)
        case "teal": return Color(0, 0.5, 0.5)
        case "olive": return Color(0.5, 0.5, 0)
        case "lime": return Color(0, 1, 0)
        case "aqua": return Color(0, 1, 1)
        case "fuchsia": return Color(1, 0, 1)
        default: return nil
        }
    }

    private func parseLineCap(_ value: String) -> CGLineCap {
        switch value { case "round": .round; case "square": .square; default: .butt }
    }

    private func parseLineJoin(_ value: String) -> CGLineJoin {
        switch value { case "round": .round; case "bevel": .bevel; default: .miter }
    }

    private func parseTransform(_ value: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        guard let regex = try? NSRegularExpression(pattern: #"(\w+)\(([^)]+)\)"#) else { return transform }
        let nsValue = value as NSString
        for match in regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length)) {
            let fn = nsValue.substring(with: match.range(at: 1))
            let args = nsValue.substring(with: match.range(at: 2))
                .split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            switch fn {
            case "translate" where args.count >= 1:
                transform = transform.translatedBy(x: CGFloat(args[0]), y: args.count >= 2 ? CGFloat(args[1]) : 0)
            case "scale" where args.count >= 1:
                transform = transform.scaledBy(x: CGFloat(args[0]), y: args.count >= 2 ? CGFloat(args[1]) : CGFloat(args[0]))
            case "rotate" where args.count >= 1:
                transform = transform.rotated(by: CGFloat(args[0] * .pi / 180))
            case "matrix" where args.count == 6:
                transform = transform.concatenating(CGAffineTransform(a: CGFloat(args[0]), b: CGFloat(args[1]),
                    c: CGFloat(args[2]), d: CGFloat(args[3]), tx: CGFloat(args[4]), ty: CGFloat(args[5])))
            default: break
            }
        }
        return transform
    }

    private func parsePoints(_ value: String) -> [Point] {
        let numbers = value.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        var points: [Point] = []
        var i = 0
        while i + 1 < numbers.count { points.append(Point(numbers[i], numbers[i + 1])); i += 2 }
        return points
    }

    private func cgFloat(_ value: String?) -> CGFloat {
        guard let value, let d = Double(value) else { return 0 }; return CGFloat(d)
    }
}

/// Mutable builder used during SVG parsing to accumulate group children.
private class SVGGroupBuilder {
    let id: String; let attributes: SVGPaintAttributes; var children: [SVGElement] = []
    init(id: String, attributes: SVGPaintAttributes) { self.id = id; self.attributes = attributes }
}

/// Mutable builder used during SVG text parsing.
private class SVGTextBuilder {
    let id: String; let x: CGFloat; let y: CGFloat
    let fontSize: CGFloat; let fontFamily: String; let fontWeight: String
    let textAnchor: SVGTextAnchor; let attributes: SVGPaintAttributes
    var spans: [SVGTextSpan] = []
    init(id: String, x: CGFloat, y: CGFloat, fontSize: CGFloat, fontFamily: String, fontWeight: String,
         textAnchor: SVGTextAnchor, attributes: SVGPaintAttributes) {
        self.id = id; self.x = x; self.y = y; self.fontSize = fontSize
        self.fontFamily = fontFamily; self.fontWeight = fontWeight
        self.textAnchor = textAnchor; self.attributes = attributes
    }
}

// MARK: - SVG Path Data Parser

/// Parses SVG path `d` attribute into a Forge Path.
enum SVGPathDataParser {
    static func parse(_ d: String) -> Path {
        var path = Path()
        let tokens = tokenize(d)
        var i = 0
        var current = Point.zero
        var lastControlPoint: Point?
        var lastCommand: Character = " "
        var subpathStart = Point.zero

        func nextNumber() -> CGFloat? {
            guard i < tokens.count, case .number(let n) = tokens[i] else { return nil }; i += 1; return n
        }
        func nextPoint() -> Point? {
            guard let x = nextNumber(), let y = nextNumber() else { return nil }; return Point(Double(x), Double(y))
        }

        while i < tokens.count {
            let command: Character
            if case .command(let c) = tokens[i] { command = c; i += 1 } else { command = lastCommand }
            let isRel = command.isLowercase
            let cmd = Character(String(command).uppercased())

            switch cmd {
            case "M":
                guard let pt = nextPoint() else { break }
                let t = isRel ? Point(current.x + pt.x, current.y + pt.y) : pt
                path.move(to: t); current = t; subpathStart = t; lastControlPoint = nil
                lastCommand = isRel ? "l" : "L"; continue
            case "L":
                guard let pt = nextPoint() else { break }
                let t = isRel ? Point(current.x + pt.x, current.y + pt.y) : pt
                path.line(to: t); current = t; lastControlPoint = nil
            case "H":
                guard let x = nextNumber() else { break }
                let t = Point(isRel ? current.x + Double(x) : Double(x), current.y)
                path.line(to: t); current = t; lastControlPoint = nil
            case "V":
                guard let y = nextNumber() else { break }
                let t = Point(current.x, isRel ? current.y + Double(y) : Double(y))
                path.line(to: t); current = t; lastControlPoint = nil
            case "C":
                guard let c1 = nextPoint(), let c2 = nextPoint(), let end = nextPoint() else { break }
                let cp1 = isRel ? Point(current.x + c1.x, current.y + c1.y) : c1
                let cp2 = isRel ? Point(current.x + c2.x, current.y + c2.y) : c2
                let ep = isRel ? Point(current.x + end.x, current.y + end.y) : end
                path.curve(to: ep, control1: cp1, control2: cp2); lastControlPoint = cp2; current = ep
            case "S":
                guard let c2 = nextPoint(), let end = nextPoint() else { break }
                let cp1 = lastControlPoint.map { Point(2 * current.x - $0.x, 2 * current.y - $0.y) } ?? current
                let cp2 = isRel ? Point(current.x + c2.x, current.y + c2.y) : c2
                let ep = isRel ? Point(current.x + end.x, current.y + end.y) : end
                path.curve(to: ep, control1: cp1, control2: cp2); lastControlPoint = cp2; current = ep
            case "Q":
                guard let c1 = nextPoint(), let end = nextPoint() else { break }
                let cp = isRel ? Point(current.x + c1.x, current.y + c1.y) : c1
                let ep = isRel ? Point(current.x + end.x, current.y + end.y) : end
                path.quadCurve(to: ep, control: cp); lastControlPoint = cp; current = ep
            case "T":
                guard let end = nextPoint() else { break }
                let cp = lastControlPoint.map { Point(2 * current.x - $0.x, 2 * current.y - $0.y) } ?? current
                let ep = isRel ? Point(current.x + end.x, current.y + end.y) : end
                path.quadCurve(to: ep, control: cp); lastControlPoint = cp; current = ep
            case "A":
                guard let rx = nextNumber(), let ry = nextNumber(), let rot = nextNumber(),
                      let la = nextNumber(), let sw = nextNumber(), let end = nextPoint() else { break }
                let ep = isRel ? Point(current.x + end.x, current.y + end.y) : end
                addArc(to: &path, from: current, to: ep, rx: abs(rx), ry: abs(ry), xRotation: rot, largeArc: la != 0, sweep: sw != 0)
                current = ep; lastControlPoint = nil
            case "Z":
                path.close(); current = subpathStart; lastControlPoint = nil
            default: break
            }
            lastCommand = command
        }
        return path
    }

    // MARK: - Arc

    private static func addArc(to path: inout Path, from p1: Point, to p2: Point,
                                rx: CGFloat, ry: CGFloat, xRotation: CGFloat, largeArc: Bool, sweep: Bool) {
        guard rx > 0, ry > 0, p1 != p2 else { if p1 != p2 { path.line(to: p2) }; return }
        let phi = Double(xRotation) * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy, y1p = -sinPhi * dx + cosPhi * dy
        let rxD = Double(rx), ryD = Double(ry)
        var rxSq = rxD * rxD, rySq = ryD * ryD
        let x1pSq = x1p * x1p, y1pSq = y1p * y1p
        let lambda = x1pSq / rxSq + y1pSq / rySq
        var cRx = rxD, cRy = ryD
        if lambda > 1 { let s = sqrt(lambda); cRx = s * rxD; cRy = s * ryD; rxSq = cRx * cRx; rySq = cRy * cRy }
        let num = max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = rxSq * y1pSq + rySq * x1pSq
        var sq: Double = den > 0 ? sqrt(num / den) : 0
        if largeArc == sweep { sq = -sq }
        let cxp = sq * cRx * y1p / cRy, cyp = -sq * cRy * x1p / cRx
        let mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2
        let cx = cosPhi * cxp - sinPhi * cyp + mx, cy = sinPhi * cxp + cosPhi * cyp + my
        func angle(ux: Double, uy: Double, vx: Double, vy: Double) -> Double {
            let dot = ux * vx + uy * vy, len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a: Double = len > 0 ? acos(max(-1, min(1, dot / len))) : 0
            if ux * vy - uy * vx < 0 { a = -a }; return a
        }
        let theta1 = angle(ux: 1, uy: 0, vx: (x1p - cxp) / cRx, vy: (y1p - cyp) / cRy)
        var dTheta = angle(ux: (x1p - cxp) / cRx, uy: (y1p - cyp) / cRy, vx: (-x1p - cxp) / cRx, vy: (-y1p - cyp) / cRy)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi } else if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segAngle = dTheta / Double(segments)
        for s in 0..<segments {
            let a1 = theta1 + Double(s) * segAngle, a2 = a1 + segAngle
            let alpha = sin(segAngle) * (sqrt(4 + 3 * pow(tan(segAngle / 2), 2)) - 1) / 3
            let cos1 = cos(a1), sin1 = sin(a1), cos2 = cos(a2), sin2 = sin(a2)
            func tx(_ px: Double, _ py: Double) -> Point {
                Point(cosPhi * px - sinPhi * py + cx, sinPhi * px + cosPhi * py + cy)
            }
            let cp1 = tx(cRx * (cos1 - alpha * sin1), cRy * (sin1 + alpha * cos1))
            let cp2 = tx(cRx * (cos2 + alpha * sin2), cRy * (sin2 - alpha * cos2))
            path.curve(to: tx(cRx * cos2, cRy * sin2), control1: cp1, control2: cp2)
        }
    }

    // MARK: - Tokenizer

    private enum Token { case command(Character); case number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []; let chars = Array(d); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace || c == "," { i += 1; continue }
            if "MmLlHhVvCcSsQqTtAaZz".contains(c) { tokens.append(.command(c)); i += 1; continue }
            if c == "-" || c == "+" || c == "." || c.isNumber {
                var numStr = ""; var hasDot = false
                if c == "-" || c == "+" { numStr.append(c); i += 1 }
                while i < chars.count {
                    let ch = chars[i]
                    if ch.isNumber { numStr.append(ch); i += 1 }
                    else if ch == "." && !hasDot { hasDot = true; numStr.append(ch); i += 1 }
                    else { break }
                }
                if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                    numStr.append(chars[i]); i += 1
                    if i < chars.count && (chars[i] == "+" || chars[i] == "-") { numStr.append(chars[i]); i += 1 }
                    while i < chars.count && chars[i].isNumber { numStr.append(chars[i]); i += 1 }
                }
                if let val = Double(numStr) { tokens.append(.number(CGFloat(val))) }
                continue
            }
            i += 1
        }
        return tokens
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
