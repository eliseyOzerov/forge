/// The fundamental layout primitive. A container that paints a Surface,
/// clips to a Shape, and overlays its children (each aligned independently).
///
/// Single child = styled container. Multiple children = overlay (ZStack).
///
/// ```swift
/// Box(.frame(.fixed(200, 200))
///     .shape(.roundedRect(radius: 12))
///     .surface(.color(.white).shadow(blur: 8))
///     .padding(.all(16))
/// ) {
///     Text("Hello")
/// }
/// ```

// MARK: - Box

@Copy
public struct Box: ContainerView {
    public var style: BoxStyle = BoxStyle()
    public var children: [any View] = []

    public init(_ style: BoxStyle = BoxStyle(), @ChildrenBuilder content: () -> [any View]) {
        self.style = style
        self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        BoxRenderer(view: self)
        #else
        fatalError("Box not yet implemented for this platform")
        #endif
    }
}
// MARK: - BoxStyle

/// Visual styling for Box (layout, rendering, clipping).
@Init @Copy @Lerp
public struct BoxStyle: Equatable {
    // Layout
    public var frame: Frame = .hug
    public var padding: Padding = .zero
    public var alignment: Alignment = .center
    @Snap public var overflow: Overflow = .clip

    // Rendering
    public var surface: Surface? = nil
    public var shape: AnyShape? = nil
    @Snap public var clip: Bool = true
}

// MARK: - Box Extensions

public extension Box {
    init(_ style: BoxStyle = BoxStyle(), children: [any View] = []) {
        self.style = style
        self.children = children
    }

    init(
        frame: Frame = .hug,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        overflow: Overflow = .clip,
        surface: Surface? = nil,
        shape: AnyShape? = nil,
        clip: Bool = true,
        @ChildrenBuilder content: () -> [any View]
    ) {
        self.style = BoxStyle(frame: frame, padding: padding,
                              alignment: alignment, overflow: overflow,
                              surface: surface, shape: shape, clip: clip)
        self.children = content()
    }

    init(
        frame: Frame = .hug,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        overflow: Overflow = .clip,
        surface: Surface? = nil,
        shape: AnyShape? = nil,
        clip: Bool = true,
        children: [any View] = []
    ) {
        self.style = BoxStyle(frame: frame, padding: padding,
                              alignment: alignment, overflow: overflow,
                              surface: surface, shape: shape, clip: clip)
        self.children = children
    }

    /// Configure style. The callback receives the current style for modification.
    func style(_ build: (BoxStyle) -> BoxStyle) -> Box {
        copy { $0.style = build($0.style) }
    }
}

// MARK: - View Extensions

public extension View {
    func centered() -> Box {
        aligned(.center)
    }

    func padded(_ padding: Padding) -> Box {
        Box(padding: padding) { self }
    }

    func padded(_ value: Double) -> Box {
        Box(padding: .all(value)) { self }
    }

    func aligned(_ alignment: Alignment, fill: Frame = .fill) -> Box {
        Box(frame: fill, alignment: alignment) { self }
    }

    func framed(_ frame: Frame) -> Box {
        Box(frame: frame) { self }
    }
}

// MARK: - BoxRole

/// Named box role token.
public struct BoxRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension BoxRole {
    static let primary    = BoxRole("primary")
    static let secondary  = BoxRole("secondary")
    static let tertiary   = BoxRole("tertiary")
    static let quaternary = BoxRole("quaternary")

    static let defaultChain: [BoxRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - BoxTheme

/// Role-keyed BoxStyles with cascade. Surfaces, cards, panels read
/// via `ctx.theme(.box).primary`.
public struct BoxTheme: Copyable {
    public var styles: [BoxRole: BoxStyle]
    public var chain: [BoxRole]

    public init(_ styles: [BoxRole: BoxStyle], chain: [BoxRole] = BoxRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<BoxStyle>) {
        var map: [BoxRole: BoxStyle] = [:]
        for (level, style) in priority.values {
            map[BoxRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: BoxStyle,
        secondary: BoxStyle? = nil,
        tertiary: BoxStyle? = nil,
        quaternary: BoxStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: BoxRole) -> BoxStyle {
        styles.cascade(role, chain: chain) ?? BoxStyle()
    }

    public var primary:    BoxStyle { self[.primary] }
    public var secondary:  BoxStyle { self[.secondary] }
    public var tertiary:   BoxStyle { self[.tertiary] }
    public var quaternary: BoxStyle { self[.quaternary] }

    public static func standard() -> BoxTheme {
        BoxTheme(primary: BoxStyle())
    }
}

public extension ThemeSlot where T == BoxTheme {
    static var box: ThemeSlot<BoxTheme> { .init(BoxTheme.self) }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class BoxRenderer: ContainerRenderer {
    private weak var rendered: BoxView?
    private var view: Box

    init(view: Box) {
        self.view = view
    }

    func mount() -> PlatformView {
        let bv = BoxView()
        self.rendered = bv
        bv.apply(view.style)
        return bv
    }

    func update(from newView: any View) {
        guard let box = newView as? Box, let rendered else { return }
        let oldStyle = view.style
        view = box
        if oldStyle != view.style {
            rendered.apply(view.style)
        }
    }
}

// MARK: - BoxView

/// The backing UIView for Box. Handles surface painting, child layout
/// (alignment-based positioning), frame constraints, shape clipping,
/// and optional scroll overflow.
class BoxView: UIView {

    // MARK: - Layout Properties

    var sizing: Frame = .hug {
        didSet {
            guard sizing != oldValue else { return }
            invalidateSize()
        }
    }
    var padding: Padding = .zero {
        didSet {
            guard padding != oldValue else { return }
            invalidateSize()
        }
    }
    var alignment: Alignment = .center
    var overflow: Overflow = .clip

    // MARK: - Rendering Properties

    var surface: Surface? {
        didSet {
            surfaceView.surface = surface;
            layoutSurfaceView()
        }
    }
    var shape: AnyShape?
    var clip: Bool = true

    // MARK: - Internal State

    private let surfaceView = SurfaceView()
    private var lastClipShape: AnyShape?
    private var lastClipBounds: CGRect = .zero
    private var lastClipEnabled: Bool = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        super.addSubview(surfaceView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ style: BoxStyle) {
        sizing = style.frame
        padding = style.padding
        alignment = style.alignment
        overflow = style.overflow
        surface = style.surface
        shape = style.shape
        clip = style.clip
    }

    // MARK: - Surface

    private func layoutSurfaceView() {
        guard surface != nil else {
            surfaceView.frame = .zero
            surfaceView.path = nil
            return
        }

        let resolvedShape: AnyShape = shape ?? RectShape().erased
        let viewRect = Rect(bounds)
        let path = resolvedShape.path(in: viewRect)
        let pathRect = path.boundingBox

        surfaceView.frame = pathRect.cgRect
        surfaceView.path = path
        surfaceView.setNeedsDisplay()
    }

    // MARK: - Sizing

    private var sizeCache: (proposed: Size, result: Size)?
    private var childSizeCache: [ObjectIdentifier: (proposed: Size, result: Size)] = [:]

    /// Invalidate cached sizes and notify the parent layout.
    func invalidateSize() {
        sizeCache = nil
        childSizeCache.removeAll()
        superview?.setNeedsLayout()
    }

    override func setNeedsLayout() {
        super.setNeedsLayout()
        sizeCache = nil
        childSizeCache.removeAll()
    }

    /// How big this view wants to be given a proposal.
    ///
    /// - **fix** — exact value, ignores proposal and children.
    /// - **fill** — fraction of proposed, clamped.
    /// - **fit** — content size + padding (intrinsic size), clamped.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let proposed = Size(size)
        if let cached = sizeCache, cached.proposed == proposed {
            return cached.result.cgSize
        }
        let inner = innerBounds(proposed)
        let content = measureChildren(inner)
        let result = outerBounds(proposed: proposed, content: content)
        sizeCache = (proposed, result)
        return result.cgSize
    }

    /// Measure children within the given inner bounds, returning the largest child size.
    func measureChildren(_ innerSize: Size) -> Size {
        contentChildren.reduce(into: Size.zero) { result, child in
            let s = measureChild(child, proposed: innerSize)
            result = Size(max(result.width, s.width), max(result.height, s.height))
        }
    }

    /// Measure a single child, returning a cached result if the proposal hasn't changed.
    private func measureChild(_ child: UIView, proposed: Size) -> Size {
        let key = ObjectIdentifier(child)
        if let cached = childSizeCache[key], cached.proposed == proposed {
            return cached.result
        }
        let result = Size(child.sizeThatFits(proposed.cgSize))
        childSizeCache[key] = (proposed, result)
        return result
    }

    /// The inner bounds available to children after resolving the frame and subtracting padding.
    func innerBounds(_ proposed: Size) -> Size {
        func resolve(_ extent: Extent, _ proposed: Double, _ padding: Double) -> Double {
            switch extent {
            case .fix(let value): value - padding
            case .fill(let fraction, let min, let max): (proposed * fraction).clamped(min: min, max: max) - padding
            case .fit(let min, let max): (proposed - padding).clamped(min: min, max: max)
            }
        }
        return Size(
            resolve(sizing.width, proposed.width, padding.horizontal),
            resolve(sizing.height, proposed.height, padding.vertical)
        )
    }

    /// The outer size of the box. fix/fill are self-determined; fit wraps content + padding.
    func outerBounds(proposed: Size, content: Size) -> Size {
        func resolve(_ extent: Extent, _ proposed: Double, _ content: Double, _ padding: Double) -> Double {
            switch extent {
            case .fix(let value): value
            case .fill(let fraction, let min, let max): (proposed * fraction).clamped(min: min, max: max)
            case .fit(let min, let max): (content + padding).clamped(min: min, max: max)
            }
        }
        return Size(
            resolve(sizing.width, proposed.width, content.width, padding.horizontal),
            resolve(sizing.height, proposed.height, content.height, padding.vertical)
        )
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSurfaceView()
        layoutChildren()
        applyShapeClip()
    }

    /// Position each child within the padded inset rect, aligned by alignment.
    private func layoutChildren() {
        let inset = Rect(bounds) - padding

        for child in contentChildren {
            let childSize = measureChild(child, proposed: inset.size)
            child.frame = childSize.aligned(alignment, in: inset).cgRect
        }
    }

    /// Apply shape mask for clipping. Caches to avoid re-creating
    /// the mask layer every layout pass when nothing changed.
    private func applyShapeClip() {
        // Determine effective clipping based on overflow
        let effectiveClip: Bool
        switch overflow {
        case .visible: effectiveClip = false
        default: effectiveClip = clip
        }

        if effectiveClip {
            if let shape {
                // Only rebuild if shape, bounds, or clip state changed
                if shape != lastClipShape || bounds != lastClipBounds || lastClipEnabled != effectiveClip {
                    let maskLayer = CAShapeLayer()
                    maskLayer.path = shape.path(in: Rect(bounds)).cgPath
                    layer.mask = maskLayer
                    clipsToBounds = false
                    lastClipShape = shape
                    lastClipBounds = bounds
                    lastClipEnabled = effectiveClip
                }
            } else {
                // No shape — use clipsToBounds for rectangular clipping
                layer.mask = nil
                clipsToBounds = true
                lastClipShape = nil
                lastClipBounds = bounds
                lastClipEnabled = effectiveClip
            }
        } else {
            if lastClipEnabled != effectiveClip {
                layer.mask = nil
                clipsToBounds = false
                lastClipShape = nil
                lastClipBounds = .zero
                lastClipEnabled = effectiveClip
            }
        }
    }

    /// The content children (excludes the internal surface view).
    private var contentChildren: [UIView] {
        super.subviews.filter { $0 !== surfaceView }
    }

    // MARK: - Subview Routing

    override func addSubview(_ view: UIView) {
        super.addSubview(view)
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        // Offset by 1 for the internal surfaceView
        super.insertSubview(view, at: index + 1)
    }

    override var subviews: [UIView] {
        super.subviews.filter { $0 !== surfaceView }
    }
}

// MARK: - SurfaceView

/// Paints a Surface's layers for a pre-resolved path. Sized to the
/// path's bounding box — can extend beyond the parent BoxView's
/// bounds for shapes that overflow (scaled, transformed, etc.).
class SurfaceView: UIView {
    var surface: Surface?
    var path: Path?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let path, let surface, let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.translateBy(x: -frame.origin.x, y: -frame.origin.y)
        let canvas = CGCanvas(ctx)
        let context = SurfaceContext(canvas: canvas, path: path, bounds: Rect(frame))
        for layer in surface.layers { layer.render(in: context) }
    }
}

#endif
