import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Graphic

/// Vector graphic component. Parses SVG data, renders into a cached bitmap.
public struct Graphic: LeafView {
    public var source: GraphicSource
    public var style: GraphicStyle

    public init(svg: String, style: GraphicStyle = GraphicStyle()) {
        self.source = .string(svg); self.style = style
    }

    public init(data: Data, style: GraphicStyle = GraphicStyle()) {
        self.source = .data(data); self.style = style
    }

    public init(asset name: String, style: GraphicStyle = GraphicStyle()) {
        self.source = .asset(name); self.style = style
    }

    public init(file url: URL, style: GraphicStyle = GraphicStyle()) {
        self.source = .file(url); self.style = style
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        GraphicUIKitRenderer(view: self)
        #else
        fatalError("Graphic not yet implemented for this platform")
        #endif
    }
}

public extension Graphic {
    /// Configure style. The callback receives the current style for modification.
    func style(_ build: (GraphicStyle) -> GraphicStyle) -> Graphic {
        var copy = self
        copy.style = build(style)
        return copy
    }
}

// MARK: - GraphicStyle

/// Visual style for a graphic (tint color, size, per-element overrides).
@Init @Copy
public struct GraphicStyle {
    public var color: Color? = nil
    public var size: CGSize? = nil
    public var overrides: [String: SVGOverride] = [:]
}

// MARK: - GraphicSource

/// Source of SVG data (inline string, Data, asset name, or file URL).
public enum GraphicSource {
    case string(String)
    case data(Data)
    case asset(String)
    case file(URL)
}

// MARK: - Renderer

#if canImport(UIKit)

final class GraphicUIKitRenderer: Renderer {
    private weak var graphicView: GraphicView?
    private var view: Graphic

    init(view: Graphic) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let graphic = newView as? Graphic, let graphicView else { return }
        let old = view
        view = graphic

        let sourceChanged = !sourceEqual(old.source, graphic.source)
        if sourceChanged {
            applyDocument(to: graphicView)
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        let oldStyle = old.style
        let newStyle = graphic.style

        if oldStyle.size != newStyle.size {
            graphicView.graphicSize = newStyle.size
            graphicView.invalidateIntrinsicContentSize()
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        let colorChanged = oldStyle.color != newStyle.color
        if colorChanged {
            graphicView.graphicColor = newStyle.color
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
        }

        graphicView.graphicOverrides = newStyle.overrides
        if !sourceChanged && !colorChanged {
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
        }
    }

    func mount() -> PlatformView {
        let gv = GraphicView()
        self.graphicView = gv
        applyDocument(to: gv)
        gv.graphicColor = view.style.color
        gv.graphicSize = view.style.size
        gv.graphicOverrides = view.style.overrides
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
        default: return false
        }
    }
}

// MARK: - GraphicView

final class GraphicView: UIView {
    var document: SVGDocument?
    var graphicColor: Color?
    var graphicSize: CGSize?
    var graphicOverrides: [String: SVGOverride] = [:]
    var cachedImage: UIImage?
    private var cachedBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

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
