import Foundation
import CoreGraphics

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
public struct SVGPolygonData { public let id: String; public let points: [CGPoint]; public let attributes: SVGPaintAttributes }
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

    private func parsePoints(_ value: String) -> [CGPoint] {
        let numbers = value.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        var points: [CGPoint] = []
        var i = 0
        while i + 1 < numbers.count { points.append(CGPoint(x: numbers[i], y: numbers[i + 1])); i += 2 }
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
        var current = CGPoint.zero
        var lastControlPoint: CGPoint?
        var lastCommand: Character = " "
        var subpathStart = CGPoint.zero

        func nextNumber() -> CGFloat? {
            guard i < tokens.count, case .number(let n) = tokens[i] else { return nil }; i += 1; return n
        }
        func nextPoint() -> CGPoint? {
            guard let x = nextNumber(), let y = nextNumber() else { return nil }; return CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            let command: Character
            if case .command(let c) = tokens[i] { command = c; i += 1 } else { command = lastCommand }
            let isRel = command.isLowercase
            let cmd = Character(String(command).uppercased())

            switch cmd {
            case "M":
                guard let pt = nextPoint() else { break }
                let t = isRel ? CGPoint(x: current.x + pt.x, y: current.y + pt.y) : pt
                path.move(to: t); current = t; subpathStart = t; lastControlPoint = nil
                lastCommand = isRel ? "l" : "L"; continue
            case "L":
                guard let pt = nextPoint() else { break }
                let t = isRel ? CGPoint(x: current.x + pt.x, y: current.y + pt.y) : pt
                path.line(to: t); current = t; lastControlPoint = nil
            case "H":
                guard let x = nextNumber() else { break }
                let t = CGPoint(x: isRel ? current.x + x : x, y: current.y)
                path.line(to: t); current = t; lastControlPoint = nil
            case "V":
                guard let y = nextNumber() else { break }
                let t = CGPoint(x: current.x, y: isRel ? current.y + y : y)
                path.line(to: t); current = t; lastControlPoint = nil
            case "C":
                guard let c1 = nextPoint(), let c2 = nextPoint(), let end = nextPoint() else { break }
                let cp1 = isRel ? CGPoint(x: current.x + c1.x, y: current.y + c1.y) : c1
                let cp2 = isRel ? CGPoint(x: current.x + c2.x, y: current.y + c2.y) : c2
                let ep = isRel ? CGPoint(x: current.x + end.x, y: current.y + end.y) : end
                path.curve(to: ep, control1: cp1, control2: cp2); lastControlPoint = cp2; current = ep
            case "S":
                guard let c2 = nextPoint(), let end = nextPoint() else { break }
                let cp1 = lastControlPoint.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let cp2 = isRel ? CGPoint(x: current.x + c2.x, y: current.y + c2.y) : c2
                let ep = isRel ? CGPoint(x: current.x + end.x, y: current.y + end.y) : end
                path.curve(to: ep, control1: cp1, control2: cp2); lastControlPoint = cp2; current = ep
            case "Q":
                guard let c1 = nextPoint(), let end = nextPoint() else { break }
                let cp = isRel ? CGPoint(x: current.x + c1.x, y: current.y + c1.y) : c1
                let ep = isRel ? CGPoint(x: current.x + end.x, y: current.y + end.y) : end
                path.quadCurve(to: ep, control: cp); lastControlPoint = cp; current = ep
            case "T":
                guard let end = nextPoint() else { break }
                let cp = lastControlPoint.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let ep = isRel ? CGPoint(x: current.x + end.x, y: current.y + end.y) : end
                path.quadCurve(to: ep, control: cp); lastControlPoint = cp; current = ep
            case "A":
                guard let rx = nextNumber(), let ry = nextNumber(), let rot = nextNumber(),
                      let la = nextNumber(), let sw = nextNumber(), let end = nextPoint() else { break }
                let ep = isRel ? CGPoint(x: current.x + end.x, y: current.y + end.y) : end
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

    private static func addArc(to path: inout Path, from p1: CGPoint, to p2: CGPoint,
                                rx: CGFloat, ry: CGFloat, xRotation: CGFloat, largeArc: Bool, sweep: Bool) {
        guard rx > 0, ry > 0, p1 != p2 else { if p1 != p2 { path.line(to: p2) }; return }
        let phi = xRotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy, y1p = -sinPhi * dx + cosPhi * dy
        var rxSq = rx * rx, rySq = ry * ry
        let x1pSq = x1p * x1p, y1pSq = y1p * y1p
        let lambda = x1pSq / rxSq + y1pSq / rySq
        var cRx = rx, cRy = ry
        if lambda > 1 { let s = sqrt(lambda); cRx = s * rx; cRy = s * ry; rxSq = cRx * cRx; rySq = cRy * cRy }
        let num = max(0, rxSq * rySq - rxSq * y1pSq - rySq * x1pSq)
        let den = rxSq * y1pSq + rySq * x1pSq
        var sq: CGFloat = den > 0 ? sqrt(num / den) : 0
        if largeArc == sweep { sq = -sq }
        let cxp = sq * cRx * y1p / cRy, cyp = -sq * cRy * x1p / cRx
        let mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2
        let cx = cosPhi * cxp - sinPhi * cyp + mx, cy = sinPhi * cxp + cosPhi * cyp + my
        func angle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy, len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a: CGFloat = len > 0 ? acos(max(-1, min(1, dot / len))) : 0
            if ux * vy - uy * vx < 0 { a = -a }; return a
        }
        let theta1 = angle(ux: 1, uy: 0, vx: (x1p - cxp) / cRx, vy: (y1p - cyp) / cRy)
        var dTheta = angle(ux: (x1p - cxp) / cRx, uy: (y1p - cyp) / cRy, vx: (-x1p - cxp) / cRx, vy: (-y1p - cyp) / cRy)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi } else if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segAngle = dTheta / CGFloat(segments)
        for s in 0..<segments {
            let a1 = theta1 + CGFloat(s) * segAngle, a2 = a1 + segAngle
            let alpha = sin(segAngle) * (sqrt(4 + 3 * pow(tan(segAngle / 2), 2)) - 1) / 3
            let cos1 = cos(a1), sin1 = sin(a1), cos2 = cos(a2), sin2 = sin(a2)
            func tx(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
                CGPoint(x: cosPhi * px - sinPhi * py + cx, y: sinPhi * px + cosPhi * py + cy)
            }
            let cp1 = tx(cRx * (cos1 - alpha * sin1), cRy * (sin1 + alpha * cos1))
            let cp2 = tx(cRx * (cos2 + alpha * sin2), cRy * (sin2 - alpha * cos2))
            path.curve(to: tx(cRx * cos2, cRy * sin2), control1: cp1, control2: cp2)
        }
    }

    // MARK: - Tokenizer

    private enum Token { case command(Character); case number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []; var chars = Array(d); var i = 0
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
