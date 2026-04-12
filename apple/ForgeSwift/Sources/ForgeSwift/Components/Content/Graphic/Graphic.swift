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
        GraphicRenderer(source: source, color: color, size: size, overrides: overrides)
    }
}

public enum GraphicSource {
    case string(String)
    case data(Data)
    case asset(String)
    case file(URL)
    case url(URL)
}

// MARK: - Renderer

final class GraphicRenderer: Renderer {
    let source: GraphicSource
    let color: Color?
    let size: CGSize?
    let overrides: [String: GraphicOverride]

    init(source: GraphicSource, color: Color?, size: CGSize?, overrides: [String: GraphicOverride]) {
        self.source = source; self.color = color; self.size = size; self.overrides = overrides
    }

    func mount() -> PlatformView {
        let view = GraphicView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? GraphicView else { return }
        apply(to: view)
    }

    private func apply(to view: GraphicView) {
        switch source {
        case .string(let svg):
            view.setDocument(SVGParser().parse(svg), color: color, size: size, overrides: overrides)
        case .data(let data):
            view.setDocument(SVGParser().parse(data), color: color, size: size, overrides: overrides)
        case .asset(let name):
            if let asset = NSDataAsset(name: name) {
                view.setDocument(SVGParser().parse(asset.data), color: color, size: size, overrides: overrides)
            } else if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
                      let data = try? Data(contentsOf: url) {
                view.setDocument(SVGParser().parse(data), color: color, size: size, overrides: overrides)
            } else {
                view.setDocument(nil, color: color, size: size, overrides: overrides)
            }
        case .file(let url):
            if let data = try? Data(contentsOf: url) {
                view.setDocument(SVGParser().parse(data), color: color, size: size, overrides: overrides)
            }
        case .url:
            // TODO: async loading with loading/error state
            break
        }
    }
}

// MARK: - GraphicView

final class GraphicView: UIView {
    private var document: SVGDocument?
    private var graphicColor: Color?
    private var graphicSize: CGSize?
    private var graphicOverrides: [String: GraphicOverride] = [:]
    private var cachedImage: UIImage?
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

        let builder = SVGSurfaceBuilder(document: document, overrides: graphicOverrides, globalColor: graphicColor)
        let surface = builder.build()
        let renderer = SurfaceRenderer(surface: surface, bounds: bounds)

        let imgRenderer = UIGraphicsImageRenderer(size: size)
        cachedImage = imgRenderer.image { imgCtx in
            renderer.render(in: imgCtx.cgContext)
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

#else

public struct Graphic: ComposedView {
    public init() {}
    public func build(context: BuildContext) -> any View { Text("TODO: Graphic") }
}

#endif
