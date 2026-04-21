import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Graphic

/// Vector graphic component. Parses and renders SVG illustrations with
/// content-fit scaling. More akin to Image than Icon — treats the SVG
/// as an opaque illustration rather than a tintable glyph.
/// Uses ModelView to handle async loading from various sources.
public struct Graphic: ModelView {
    public var source: GraphicOrigin
    public var style: StateProperty<GraphicStyle>

    public init(
        _ source: GraphicOrigin,
        style: StateProperty<GraphicStyle> = .constant(GraphicStyle())
    ) {
        self.source = source
        self.style = style
    }

    public func style(_ build: @escaping @MainActor (GraphicStyle, State) -> GraphicStyle) -> Graphic {
        var copy = self
        copy.style = StateProperty { state in build(GraphicStyle(), state) }
        return copy
    }

    public func model(context: ViewContext) -> GraphicModel { GraphicModel(context: context) }
    public func builder(model: GraphicModel) -> GraphicBuilder { GraphicBuilder(model: model) }
}

// MARK: - GraphicStyle

/// Visual style for a graphic (size, fit mode, state view builder for loading/error).
@Style
public struct GraphicStyle {
    public var size: Size? = nil
    @Snap public var fit: ImageFit = .cover
    @Snap public var state: StateProperty<any View>? = nil
}

// MARK: - GraphicOrigin

/// Source of SVG data (inline string, raw bytes, asset name, or file URL).
public enum GraphicOrigin: Sendable {
    case string(String)
    case data(Data)
    case asset(String)
    case file(URL)
}

// MARK: - GraphicLeaf

/// Internal leaf view that renders a parsed SVG document.
struct GraphicLeaf: LeafView {
    let document: SVGDocument
    let style: GraphicStyle

    func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        GraphicUIKitRenderer(view: self)
        #else
        fatalError("Graphic not yet implemented for this platform")
        #endif
    }
}

// MARK: - GraphicModel

/// Manages SVG parsing lifecycle for Graphic.
public final class GraphicModel: ViewModel<Graphic> {
    var loadedDocument: SVGDocument?
    var loadError: Error?
    var loadState: State = .loading

    public override func didInit(view: Graphic) {
        super.didInit(view: view)
        load(source: view.source)
    }

    public override func didUpdate(newView: Graphic) {
        let oldSource = view.source
        super.didUpdate(newView: newView)
        if !sourceEqual(oldSource, newView.source) {
            loadedDocument = nil
            loadError = nil
            loadState = .loading
            load(source: newView.source)
        }
    }

    private func load(source: GraphicOrigin) {
        switch source {
        case .string(let svg):
            parseAndStore(SVGParser().parse(svg))
        case .data(let data):
            parseAndStore(SVGParser().parse(data))
        case .asset(let name):
            loadAsset(name: name)
        case .file(let url):
            loadFile(url: url)
        }
    }

    private func parseAndStore(_ doc: SVGDocument?) {
        if let doc {
            rebuild {
                self.loadedDocument = doc
                self.loadState = .idle
            }
        } else {
            rebuild {
                self.loadError = SourceError.notFound("Failed to parse SVG")
                self.loadState = .idle
            }
        }
    }

    private func loadAsset(name: String) {
        if let data = Self.assetData(named: name) {
            parseAndStore(SVGParser().parse(data))
        } else {
            rebuild {
                self.loadError = SourceError.notFound("Asset not found: \(name)")
                self.loadState = .idle
            }
        }
    }

    private func loadFile(url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try Data(contentsOf: url)
                self.parseAndStore(SVGParser().parse(data))
            } catch {
                self.rebuild {
                    self.loadError = error
                    self.loadState = .idle
                }
            }
        }
    }

    private func sourceEqual(_ a: GraphicOrigin, _ b: GraphicOrigin) -> Bool {
        switch (a, b) {
        case (.string(let l), .string(let r)): return l == r
        case (.data(let l), .data(let r)): return l == r
        case (.asset(let l), .asset(let r)): return l == r
        case (.file(let l), .file(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - GraphicBuilder

/// Builds the graphic view or a state placeholder based on load state.
public final class GraphicBuilder: ViewBuilder<GraphicModel> {
    public override func build(context: ViewContext) -> any View {
        let style = model.view.style(model.loadState)

        if model.loadState.contains(.loading) {
            if let stateBuilder = style.state {
                return stateBuilder(model.loadState)
            }
            return Text("")
        }

        if model.loadError != nil {
            if let stateBuilder = style.state {
                return stateBuilder(model.loadState)
            }
            return Text("")
        }

        if let document = model.loadedDocument {
            return GraphicLeaf(document: document, style: style)
        }

        return Text("")
    }
}

// MARK: - UIKit

#if canImport(UIKit)

final class GraphicUIKitRenderer: Renderer {
    private weak var graphicView: GraphicCanvasView?
    private var view: GraphicLeaf

    init(view: GraphicLeaf) {
        self.view = view
    }

    func mount() -> PlatformView {
        let gv = GraphicCanvasView()
        self.graphicView = gv
        gv.document = view.document
        gv.graphicSize = view.style.size
        gv.graphicFit = view.style.fit
        return gv
    }

    func update(from newView: any View) {
        guard let leaf = newView as? GraphicLeaf, let graphicView else { return }
        let old = view
        view = leaf

        let docChanged = old.document.viewBox != leaf.document.viewBox
        if docChanged {
            graphicView.document = leaf.document
            graphicView.cachedImage = nil
            graphicView.invalidateIntrinsicContentSize()
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        if old.style.size != leaf.style.size {
            graphicView.graphicSize = leaf.style.size
            graphicView.invalidateIntrinsicContentSize()
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
            graphicView.superview?.setNeedsLayout()
        }

        if old.style.fit != leaf.style.fit {
            graphicView.graphicFit = leaf.style.fit
            graphicView.cachedImage = nil
            graphicView.setNeedsDisplay()
        }
    }
}

// MARK: - GraphicCanvasView

final class GraphicCanvasView: UIView {
    var document: SVGDocument?
    var graphicSize: Size?
    var graphicFit: ImageFit = .cover
    var cachedImage: UIImage?
    private var cachedBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let document else { return }

        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }

        if let cached = cachedImage, cachedBoundsSize == size {
            cached.draw(in: bounds)
            return
        }

        let viewBox = document.viewBox
        guard viewBox.width > 0 && viewBox.height > 0 else { return }

        let imgRenderer = UIGraphicsImageRenderer(size: size)
        cachedImage = imgRenderer.image { imgCtx in
            let ctx = imgCtx.cgContext
            let transform = fitTransform(viewBox: viewBox, into: size, fit: graphicFit)
            ctx.concatenate(transform)
            let painter = SVGPainter(document: document)
            painter.paint(on: CGCanvas(ctx))
        }
        cachedBoundsSize = size
        cachedImage?.draw(in: bounds)
    }

    override var intrinsicContentSize: CGSize {
        if let s = graphicSize { return s.cgSize }
        guard let document else { return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
        return document.viewBox.size
    }

    private func fitTransform(viewBox: CGRect, into size: CGSize, fit: ImageFit) -> CGAffineTransform {
        let scaleX = size.width / viewBox.width
        let scaleY = size.height / viewBox.height

        let scale: CGFloat
        let tx: CGFloat
        let ty: CGFloat

        switch fit {
        case .cover:
            scale = max(scaleX, scaleY)
            tx = (size.width - viewBox.width * scale) / 2 - viewBox.origin.x * scale
            ty = (size.height - viewBox.height * scale) / 2 - viewBox.origin.y * scale
            return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
        case .contain:
            scale = min(scaleX, scaleY)
            tx = (size.width - viewBox.width * scale) / 2 - viewBox.origin.x * scale
            ty = (size.height - viewBox.height * scale) / 2 - viewBox.origin.y * scale
            return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
        case .fill:
            tx = -viewBox.origin.x * scaleX
            ty = -viewBox.origin.y * scaleY
            return CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: tx, ty: ty)
        case .center:
            tx = (size.width - viewBox.width) / 2 - viewBox.origin.x
            ty = (size.height - viewBox.height) / 2 - viewBox.origin.y
            return CGAffineTransform(translationX: tx, y: ty)
        }
    }
}

extension GraphicModel {
    static func assetData(named name: String) -> Data? {
        if let asset = NSDataAsset(name: name) {
            return asset.data
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}

#elseif canImport(AppKit)
import AppKit

extension GraphicModel {
    static func assetData(named name: String) -> Data? {
        if let asset = NSDataAsset(name: name) {
            return asset.data
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}

#endif
