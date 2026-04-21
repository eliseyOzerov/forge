import Foundation
import CoreGraphics

// MARK: - Graphic

#if canImport(UIKit)
import UIKit

/// Vector graphic component. Parses SVG data, builds a Surface from it,
/// renders into a cached bitmap.
///
/// Constructors:
/// - `Graphic(svg:)` — from SVG string (synchronous)
/// - `Graphic(data:)` — from raw Data (synchronous)
/// - `Graphic(asset:)` — from bundle asset name (synchronous, optional error)
/// - `Graphic(file:)` — from file URL (async)
/// - `Graphic(url:)` — from remote URL (async)
public struct Graphic: LeafView {
    public let source: GraphicSource
    public let overrides: [String: GraphicOverride]
    public let color: Color?
    public let size: CGSize?

    public init(svg: String, color: Color? = nil, size: CGSize? = nil, overrides: [String: GraphicOverride] = [:]) {
        self.source = .string(svg)
        self.color = color; self.size = size; self.overrides = overrides
    }

    public init(data: Data, color: Color? = nil, size: CGSize? = nil, overrides: [String: GraphicOverride] = [:]) {
        self.source = .data(data)
        self.color = color; self.size = size; self.overrides = overrides
    }

    public init(asset name: String, color: Color? = nil, size: CGSize? = nil, overrides: [String: GraphicOverride] = [:]) {
        self.source = .asset(name)
        self.color = color; self.size = size; self.overrides = overrides
    }

    public init(file url: URL, color: Color? = nil, size: CGSize? = nil, overrides: [String: GraphicOverride] = [:]) {
        self.source = .file(url)
        self.color = color; self.size = size; self.overrides = overrides
    }

    public init(url: URL, color: Color? = nil, size: CGSize? = nil, overrides: [String: GraphicOverride] = [:]) {
        self.source = .url(url)
        self.color = color; self.size = size; self.overrides = overrides
    }

    public func makeRenderer() -> Renderer {
        GraphicRenderer(view: self)
    }
}

#else

public struct Graphic: BuiltView {
    public init() {}
    public func build(context: ViewContext) -> any View { Text("TODO: Graphic") }
}

#endif

// MARK: - GraphicSource

public enum GraphicSource {
    case string(String)
    case data(Data)
    case asset(String)
    case file(URL)
    case url(URL)
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

// MARK: - Renderer

#if canImport(UIKit)

final class GraphicRenderer: Renderer {
    private weak var graphicView: GraphicView?
    private var view: Graphic

    init(view: Graphic) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let graphic = newView as? Graphic, let graphicView else { return }
        let old = view
        view = graphic

        // Source changed → reload document + redraw + relayout
        let sourceChanged = !sourceEqual(old.source, graphic.source)
        if sourceChanged {
            applyDocument(to: graphicView)
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        // Size changed → relayout + redraw
        if old.size != graphic.size {
            graphicView.graphicSize = graphic.size
            graphicView.invalidateIntrinsicContentSize()
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        // Color/overrides changed → redraw only
        let colorChanged = old.color != graphic.color
        if colorChanged {
            graphicView.graphicColor = graphic.color
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
        }

        // Overrides — always apply (no Equatable)
        graphicView.graphicOverrides = graphic.overrides
        if !sourceChanged && !colorChanged {
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
        }
    }

    func mount() -> PlatformView {
        let gv = GraphicView()
        self.graphicView = gv
        applyDocument(to: gv)
        gv.graphicColor = view.color
        gv.graphicSize = view.size
        gv.graphicOverrides = view.overrides
        return gv
    }

    private func applyDocument(to gv: GraphicView) {
        let doc: SVGDocument?
        switch view.source {
        case .string(let svg):
            doc = SVGParser().parse(svg)
        case .data(let data):
            doc = SVGParser().parse(data)
        case .asset(let name):
            if let asset = NSDataAsset(name: name) {
                doc = SVGParser().parse(asset.data)
            } else if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
                      let data = try? Data(contentsOf: url) {
                doc = SVGParser().parse(data)
            } else {
                doc = nil
            }
        case .file(let url):
            doc = (try? Data(contentsOf: url)).flatMap { SVGParser().parse($0) }
        case .url:
            doc = nil
        }
        gv.document = doc
        gv.cachedImage = nil
        gv.invalidateIntrinsicContentSize()
    }

    private func sourceEqual(_ a: GraphicSource, _ b: GraphicSource) -> Bool {
        switch (a, b) {
        case (.string(let l), .string(let r)): return l == r
        case (.data(let l), .data(let r)): return l == r
        case (.asset(let l), .asset(let r)): return l == r
        case (.file(let l), .file(let r)): return l == r
        case (.url(let l), .url(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - GraphicView

final class GraphicView: UIView {
    var document: SVGDocument?
    var graphicColor: Color?
    var graphicSize: CGSize?
    var graphicOverrides: [String: GraphicOverride] = [:]
    var cachedImage: UIImage?
    private var cachedBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    func setDocument(_ document: SVGDocument?, color: Color?, size: CGSize?, overrides: [String: GraphicOverride]) {
        self.document = document
        self.graphicColor = color
        self.graphicSize = size
        self.graphicOverrides = overrides
        cachedImage = nil
        setNeedsDisplay()
        invalidateIntrinsicContentSize()
    }

    override func draw(_ rect: CGRect) {
        guard let document else { return }

        let size = bounds.size
        if let cached = cachedImage, cachedBoundsSize == size {
            cached.draw(in: bounds)
            return
        }

        let painter = SVGPainter(document: document, overrides: graphicOverrides, globalColor: graphicColor)

        let imgRenderer = UIGraphicsImageRenderer(size: size)
        cachedImage = imgRenderer.image { imgCtx in
            painter.paint(on: CGCanvas(imgCtx.cgContext))
        }
        cachedBoundsSize = size
        cachedImage?.draw(in: bounds)
    }

    override var intrinsicContentSize: CGSize {
        if let s = graphicSize { return s }
        guard let document else { return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
        return document.viewBox.size
    }
}

#endif

// MARK: - SVG Painter

/// Paints an SVGDocument directly onto a Canvas. No intermediate
/// Surface or Layer tree — just immediate draw calls.
public struct SVGPainter {
    public let document: SVGDocument
    public let overrides: [String: GraphicOverride]
    public let globalColor: Color?

    public init(document: SVGDocument, overrides: [String: GraphicOverride] = [:], globalColor: Color? = nil) {
        self.document = document
        self.overrides = overrides
        self.globalColor = globalColor
    }

    public func paint(on canvas: Canvas) {
        for element in document.elements {
            paintElement(element, on: canvas)
        }
    }

    // MARK: - Element → Canvas calls

    private func paintElement(_ element: SVGElement, on canvas: Canvas) {
        switch element {
        case .path(let data):
            let path = SVGPathDataParser.parse(data.d)
            paintDrawn(path, attributes: data.attributes, id: data.id, on: canvas)

        case .rect(let data):
            let r = Rect(x: data.x, y: data.y, width: data.width, height: data.height)
            let path = data.rx > 0 || data.ry > 0
                ? RoundedModifiedShape(base: RectShape().erased, radii: [data.rx > 0 ? data.rx : data.ry], smooth: 0).path(in: r)
                : RectShape().path(in: r)
            paintDrawn(path, attributes: data.attributes, id: data.id, on: canvas)

        case .circle(let data):
            let r = Rect.fromCircle(center: Point(data.cx, data.cy), radius: data.r)
            let path = EllipseShape().path(in: r)
            paintDrawn(path, attributes: data.attributes, id: data.id, on: canvas)

        case .ellipse(let data):
            let r = Rect(x: data.cx - data.rx, y: data.cy - data.ry, width: data.rx * 2, height: data.ry * 2)
            let path = EllipseShape().path(in: r)
            paintDrawn(path, attributes: data.attributes, id: data.id, on: canvas)

        case .line(let data):
            var attrs = data.attributes; attrs.fill = .none
            if case .none = attrs.stroke { attrs.stroke = .color(.black) }
            let path = Path.line(from: Point(Double(data.x1), Double(data.y1)), to: Point(Double(data.x2), Double(data.y2)))
            paintDrawn(path, attributes: attrs, id: data.id, on: canvas)

        case .polygon(let data):
            guard !data.points.isEmpty else { return }
            paintDrawn(Path.polygon(data.points), attributes: data.attributes, id: data.id, on: canvas)

        case .polyline(let data):
            guard !data.points.isEmpty else { return }
            paintDrawn(Path.polyline(data.points), attributes: data.attributes, id: data.id, on: canvas)

        case .group(let data):
            if overrides[data.id]?.isHidden == true { return }
            let opacity = overrides[data.id]?.opacity ?? Double(data.attributes.opacity)
            let hasTransform = data.attributes.transform != .identity

            canvas.save()
            if hasTransform { canvas.transform(Transform2D(data.attributes.transform)) }
            if opacity < 1 { canvas.setAlpha(opacity) }
            for child in data.children { paintElement(child, on: canvas) }
            canvas.restore()
        }
    }

    private func paintDrawn(_ path: Path, attributes: SVGPaintAttributes, id: String, on canvas: Canvas) {
        let ov = overrides[id]
        if ov?.isHidden == true { return }

        let opacity = ov?.opacity ?? Double(attributes.opacity)
        let hasTransform = attributes.transform != .identity

        canvas.save()
        if hasTransform { canvas.transform(Transform2D(attributes.transform)) }
        if opacity < 1 { canvas.setAlpha(opacity) }

        if let fillColor = resolveFill(attributes, override: ov) {
            canvas.draw(path, with: .color(fillColor))
        }
        if let strokeColor = resolveStroke(attributes, override: ov) {
            let width = ov?.strokeWidth ?? attributes.strokeWidth
            let stroked = path.stroked(width: width, cap: StrokeCap(attributes.strokeLineCap), join: StrokeJoin(attributes.strokeLineJoin))
            canvas.draw(stroked, with: .color(strokeColor))
        }

        canvas.restore()
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

// MARK: - SVG Document

public struct SVGDocument {
    public let viewBox: CGRect
    public let elements: [SVGElement]

    public var elementIDs: [String] {
        elements.flatMap { $0.collectIDs() }
    }
}

// MARK: - Elements

public indirect enum SVGElement {
    case path(SVGPathData)
    case rect(SVGRectData)
    case circle(SVGCircleData)
    case ellipse(SVGEllipseData)
    case line(SVGLineData)
    case polygon(SVGPolygonData)
    case polyline(SVGPolygonData)
    case group(SVGGroupData)

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
        }
    }
}

// MARK: - Element Data

public struct SVGPaintAttributes {
    public var fill: SVGPaint
    public var stroke: SVGPaint
    public var strokeWidth: CGFloat
    public var strokeLineCap: CGLineCap
    public var strokeLineJoin: CGLineJoin
    public var opacity: Double
    public var transform: CGAffineTransform

    nonisolated(unsafe) public static let defaults = SVGPaintAttributes(
        fill: .color(.black), stroke: .none, strokeWidth: 1,
        strokeLineCap: .butt, strokeLineJoin: .miter,
        opacity: 1, transform: .identity
    )
}

public enum SVGPaint {
    case none
    case color(Color)
    case currentColor
}

public struct SVGPathData { public let id: String; public let d: String; public let attributes: SVGPaintAttributes }
public struct SVGRectData { public let id: String; public let x, y, width, height, rx, ry: CGFloat; public let attributes: SVGPaintAttributes }
public struct SVGCircleData { public let id: String; public let cx, cy, r: CGFloat; public let attributes: SVGPaintAttributes }
public struct SVGEllipseData { public let id: String; public let cx, cy, rx, ry: CGFloat; public let attributes: SVGPaintAttributes }
public struct SVGLineData { public let id: String; public let x1, y1, x2, y2: CGFloat; public let attributes: SVGPaintAttributes }
public struct SVGPolygonData { public let id: String; public let points: [Point]; public let attributes: SVGPaintAttributes }
public struct SVGGroupData { public let id: String; public let attributes: SVGPaintAttributes; public let children: [SVGElement] }

// MARK: - Parser

public final class SVGParser: NSObject, XMLParserDelegate {
    private var viewBox: CGRect = .zero
    private var rootWidth: CGFloat?
    private var rootHeight: CGFloat?
    private var rootPaintAttributes: SVGPaintAttributes = .defaults
    private var elementStack: [SVGGroupBuilder] = []
    private var rootElements: [SVGElement] = []
    private var elementCounters: [String: Int] = [:]

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
        return SVGDocument(viewBox: resolvedViewBox, elements: rootElements)
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "svg": parseSVGRoot(attributes)
        case "g":
            let attrs = parsePaintAttributes(attributes)
            let id = resolveID(attributes["id"], elementName: "Group")
            elementStack.append(SVGGroupBuilder(id: id, attributes: attrs))
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
        default: break
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "g", let builder = elementStack.popLast() {
            appendElement(.group(SVGGroupData(id: builder.id, attributes: builder.attributes, children: builder.children)))
        }
    }

    // MARK: - Helpers

    private func parseSVGRoot(_ attributes: [String: String]) {
        if let vb = attributes["viewBox"] {
            let parts = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if parts.count == 4 { viewBox = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3]) }
        }
        rootWidth = attributes["width"].flatMap { parseDimension($0) }
        rootHeight = attributes["height"].flatMap { parseDimension($0) }
        rootPaintAttributes = parsePaintAttributes(attributes)
    }

    private func parseDimension(_ value: String) -> CGFloat? {
        Double(value.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "pt", with: "").trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
    }

    private func resolveID(_ explicit: String?, elementName: String) -> String {
        if let explicit { return explicit }
        let count = (elementCounters[elementName] ?? 0) + 1
        elementCounters[elementName] = count
        return "\(elementName) \(count)"
    }

    private func appendElement(_ element: SVGElement) {
        if elementStack.isEmpty { rootElements.append(element) }
        else { elementStack[elementStack.count - 1].children.append(element) }
    }

    private func parsePaintAttributes(_ attributes: [String: String]) -> SVGPaintAttributes {
        let inherited = elementStack.last?.attributes ?? rootPaintAttributes
        var result = inherited
        result.transform = .identity
        if let fill = attributes["fill"] { result.fill = parsePaint(fill) }
        if let stroke = attributes["stroke"] { result.stroke = parsePaint(stroke) }
        if let sw = attributes["stroke-width"], let val = Double(sw) { result.strokeWidth = CGFloat(val) }
        if let cap = attributes["stroke-linecap"] { result.strokeLineCap = parseLineCap(cap) }
        if let join = attributes["stroke-linejoin"] { result.strokeLineJoin = parseLineJoin(join) }
        if let opacity = attributes["opacity"], let val = Double(opacity) { result.opacity = val }
        if let fillOpacity = attributes["fill-opacity"], let val = Double(fillOpacity) { result.opacity *= val }
        if let transform = attributes["transform"] { result.transform = parseTransform(transform) }
        return result
    }

    private func parsePaint(_ value: String) -> SVGPaint {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed == "none" { return .none }
        if trimmed == "currentColor" { return .currentColor }
        if let color = parseColor(trimmed) { return .color(color) }
        return .color(.black)
    }

    private func parseColor(_ value: String) -> Color? {
        if value.hasPrefix("#") { return hexColor(value) }
        switch value.lowercased() {
        case "black": return .black; case "white": return .white
        case "red": return .red; case "green": return .green; case "blue": return .blue
        default: return nil
        }
    }

    private func hexColor(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("#") { str.removeFirst() }
        if str.count == 3 { str = str.map { "\($0)\($0)" }.joined() }
        guard str.count == 6, let val = UInt64(str, radix: 16) else { return nil }
        return Color(CGFloat((val >> 16) & 0xFF) / 255, CGFloat((val >> 8) & 0xFF) / 255, CGFloat(val & 0xFF) / 255)
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

private class SVGGroupBuilder {
    let id: String; let attributes: SVGPaintAttributes; var children: [SVGElement] = []
    init(id: String, attributes: SVGPaintAttributes) { self.id = id; self.attributes = attributes }
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
