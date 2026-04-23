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

        guard oldStyle != box.style else { return }

        let needsParentLayout = oldStyle.frame != box.style.frame
        rendered.apply(box.style)
        rendered.setNeedsLayout()
        if needsParentLayout { rendered.superview?.setNeedsLayout() }
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
            guard sizing != oldValue else { return };
            updateSizingConstraints()
        }
    }
    var padding: Padding = .zero
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
    private var sizingConstraints: [NSLayoutConstraint] = []
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

    /// How big this view wants to be given a proposal.
    ///
    /// - **fix** — exact value, ignores proposal and children.
    /// - **fill** — fraction of proposed. `fill(0.5)` = half.
    /// - **flex / hug** — content size + padding (intrinsic size).
    ///
    /// Min/max on fill, flex, and hug clamp the result.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let innerSize = CGSize(
            width: max(0, size.width - padding.horizontal),
            height: max(0, size.height - padding.vertical)
        )
        var maxW: CGFloat = 0, maxH: CGFloat = 0
        for child in contentChildren {
            let s = child.sizeThatFits(size)
            maxW = max(maxW, s.width)
            maxH = max(maxH, s.height)
        }
        let width = maxW + padding.horizontal
        let height = maxH + padding.vertical

        func resolve(_ extent: Extent, _ proposed: CGFloat, _ content: CGFloat) -> CGFloat {
            let raw: Double = switch extent {
            case .fix(let v): v
            case .fill(let f, _, _): Double(proposed) * f
            case .flex, .hug: Double(content)
            }
            return CGFloat(raw.clamped(min: extent.min, max: extent.max))
        }

        return CGSize(
            width: resolve(sizing.width, size.width, width),
            height: resolve(sizing.height, size.height, height)
        )
    }

    // MARK: - Frame Constraints

    /// When added to a parent, apply Auto Layout constraints for
    /// this box's own sizing: fix → width/height, fill → pin to parent.
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateSizingConstraints()
    }

    /// Tear down old sizing constraints and install new ones matching
    /// the current `sizing` mode. Safe to call at any time.
    private func updateSizingConstraints() {
        NSLayoutConstraint.deactivate(sizingConstraints)
        sizingConstraints.removeAll()
        guard let superview else { return }
        // Inside a PassthroughView (ComposedNode wrapper), attach() pins
        // to fill — don't add conflicting constraints.
        guard !(superview is PassthroughView) else { return }
        translatesAutoresizingMaskIntoConstraints = false
        switch sizing.width {
        case .fix(let w): sizingConstraints.append(widthAnchor.equal(w))
        case .fill, .flex:
            sizingConstraints.append(leadingAnchor.equal(superview.leadingAnchor))
            sizingConstraints.append(trailingAnchor.equal(superview.trailingAnchor))
        case .hug: break
        }
        switch sizing.height {
        case .fix(let h): sizingConstraints.append(heightAnchor.equal(h))
        case .fill, .flex:
            sizingConstraints.append(topAnchor.equal(superview.topAnchor))
            sizingConstraints.append(bottomAnchor.equal(superview.bottomAnchor))
        case .hug: break
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSurfaceView()
        layoutChildren()
        applyShapeClip()
    }

    /// Position each child within the padded inset rect, aligned
    /// by alignment. Fill children get the full inset dimension
    /// on their fill axis.
    private func layoutChildren() {
        let inset = paddedInset
        let children = contentChildren

        for child in children {
            let childSize = resolveChildSize(child, in: inset)
            let origin = alignedOrigin(childSize: childSize, in: inset)
            child.frame = CGRect(origin: origin, size: childSize)
        }
    }

    /// The content area after padding.
    private var paddedInset: CGRect {
        CGRect(
            x: padding.leading, y: padding.top,
            width: bounds.width - padding.leading - padding.trailing,
            height: bounds.height - padding.top - padding.bottom
        )
    }

    /// Measure a child, respecting fill extents.
    private func resolveChildSize(_ child: UIView, in inset: CGRect) -> CGSize {
        var size = child.sizeThatFits(CGSize(width: inset.width, height: inset.height))
        // Fill/flex children expand to fill the inset on that axis
        if let boxChild = child as? BoxView {
            switch boxChild.sizing.width {
            case .fill, .flex: size.width = inset.width
            default: break
            }
            switch boxChild.sizing.height {
            case .fill, .flex: size.height = inset.height
            default: break
            }
        }
        return size
    }

    /// Compute origin for a child of given size within the inset.
    private func alignedOrigin(childSize: CGSize, in inset: CGRect) -> CGPoint {
        let fx = (alignment.x + 1) / 2
        let fy = (alignment.y + 1) / 2
        let x = inset.minX + max(0, inset.width - childSize.width) * fx
        let y = inset.minY + max(0, inset.height - childSize.height) * fy
        return CGPoint(x: x, y: y)
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
