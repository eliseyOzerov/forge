import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Icon

/// Custom SVG icon component. Renders an SVG asset with uniform color
/// and weight-derived stroke thickness. For platform system icons
/// (SF Symbols / Material Symbols), use Symbol instead.
public struct Icon: LeafView {
    public var source: IconSource
    public var style: IconStyle

    public init(_ asset: String, style: IconStyle = IconStyle()) {
        self.source = .asset(asset)
        self.style = style
    }

    public init(svg: String, style: IconStyle = IconStyle()) {
        self.source = .svg(svg)
        self.style = style
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        UIKitIconRenderer(view: self)
        #else
        fatalError("Icon not yet implemented for this platform")
        #endif
    }
}

public extension Icon {
    /// Configure style. The callback receives the current style for modification.
    func style(_ build: (IconStyle) -> IconStyle) -> Icon {
        var copy = self
        copy.style = build(style)
        return copy
    }
}

// MARK: - IconSource

/// Source of icon SVG data (asset name or inline SVG string).
public enum IconSource: Sendable, Equatable {
    case asset(String)
    case svg(String)
}

// MARK: - IconStyle

/// Visual style for a custom SVG icon (size, color, weight, thickness).
/// Weight resolves to thickness via the WeightScale on TokenTheme.
/// Explicit thickness overrides weight at render time.
@Init @Copy
public struct IconStyle {
    public var size: Double = 24
    public var color: Color? = nil
    @Snap public var weight: Weight? = nil
    public var thickness: Double? = nil
}

// MARK: - IconRole

/// Named icon role token.
public struct IconRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension IconRole {
    static let primary    = IconRole("primary")
    static let secondary  = IconRole("secondary")
    static let tertiary   = IconRole("tertiary")
    static let quaternary = IconRole("quaternary")

    static let defaultChain: [IconRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - IconTheme

/// Theme for icons with per-role style defaults.
public struct IconTheme: Copyable {
    public var styles: [IconRole: IconStyle]
    public var chain: [IconRole]

    public init(_ styles: [IconRole: IconStyle], chain: [IconRole] = IconRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<IconStyle>) {
        var map: [IconRole: IconStyle] = [:]
        for (level, style) in priority.values {
            map[IconRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: IconStyle,
        secondary: IconStyle? = nil,
        tertiary: IconStyle? = nil,
        quaternary: IconStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: IconRole) -> IconStyle {
        styles.cascade(role, chain: chain) ?? IconStyle()
    }

    public var primary:    IconStyle { self[.primary] }
    public var secondary:  IconStyle { self[.secondary] }
    public var tertiary:   IconStyle { self[.tertiary] }
    public var quaternary: IconStyle { self[.quaternary] }

    public static func standard() -> IconTheme {
        IconTheme(primary: IconStyle())
    }
}

public extension ThemeSlot where T == IconTheme {
    static var icon: ThemeSlot<IconTheme> { .init(IconTheme.self) }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)

final class UIKitIconRenderer: Renderer {
    private weak var iconView: IconCanvasView?
    private var view: Icon

    init(view: Icon) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let icon = newView as? Icon, let iconView else { return }
        let old = view
        view = icon

        let sourceChanged = old.source != icon.source
        if sourceChanged {
            applyDocument(to: iconView)
        }

        let oldStyle = old.style
        let newStyle = icon.style

        if oldStyle.size != newStyle.size {
            iconView.iconSize = newStyle.size
            iconView.invalidateIntrinsicContentSize()
            iconView.cachedImage = nil
            iconView.setNeedsDisplay()
            iconView.superview?.setNeedsLayout()
        }

        if oldStyle.color != newStyle.color {
            iconView.iconColor = newStyle.color
            iconView.cachedImage = nil
            iconView.setNeedsDisplay()
        }

        if oldStyle.thickness != newStyle.thickness || oldStyle.weight != newStyle.weight {
            iconView.iconThickness = newStyle.thickness
            iconView.iconWeight = newStyle.weight
            iconView.cachedImage = nil
            iconView.setNeedsDisplay()
        }
    }

    func mount() -> PlatformView {
        let iv = IconCanvasView()
        self.iconView = iv
        applyDocument(to: iv)
        iv.iconSize = view.style.size
        iv.iconColor = view.style.color
        iv.iconThickness = view.style.thickness
        iv.iconWeight = view.style.weight
        return iv
    }

    private func applyDocument(to iv: IconCanvasView) {
        let doc: SVGDocument?
        switch view.source {
        case .asset(let name):
            if let asset = NSDataAsset(name: name) {
                doc = SVGParser().parse(asset.data)
            } else if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
                      let data = try? Data(contentsOf: url) {
                doc = SVGParser().parse(data)
            } else {
                doc = nil
            }
        case .svg(let string):
            doc = SVGParser().parse(string)
        }
        iv.document = doc
        iv.cachedImage = nil
        iv.invalidateIntrinsicContentSize()
        iv.setNeedsDisplay()
    }
}

// MARK: - IconCanvasView

final class IconCanvasView: UIView {
    var document: SVGDocument?
    var iconSize: Double = 24
    var iconColor: Color?
    var iconThickness: Double?
    var iconWeight: Weight?
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

        // Resolve thickness: explicit > weight-derived > nil (use SVG native)
        let resolvedThickness: Double?
        if let thickness = iconThickness {
            resolvedThickness = thickness
        } else if let weight = iconWeight {
            // Weight resolves via WeightScale; fall back to standard defaults
            resolvedThickness = WeightScale.standard().thickness(for: weight)
        } else {
            resolvedThickness = nil
        }

        var painter = SVGPainter(document: document)
        painter.globalColor = iconColor
        painter.globalStrokeWidth = resolvedThickness

        let imgRenderer = UIGraphicsImageRenderer(size: size)
        cachedImage = imgRenderer.image { imgCtx in
            painter.paint(on: CGCanvas(imgCtx.cgContext))
        }
        cachedBoundsSize = size
        cachedImage?.draw(in: bounds)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: iconSize, height: iconSize)
    }
}

#endif
