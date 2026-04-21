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

@Init @Copy @Lerp
public struct BoxStyle: Equatable {
    public var frame: Frame = .hug
    public var surface: Surface? = nil
    public var shape: AnyShape? = nil
    public var padding: Padding = .zero
    public var alignment: Alignment = .center
    @Snap public var clip: Bool = true
    @Snap public var overflow: Overflow = .clip
}

// MARK: - Box

@Init
public struct Box: ContainerView {
    public var frame: Frame = .hug
    public var surface: Surface? = nil
    public var shape: AnyShape? = nil
    public var padding: Padding = .zero
    public var alignment: Alignment = .center
    public var clip: Bool = true
    public var overflow: Overflow = .clip
    public var children: [any View] = []

    public init(
        frame: Frame = .hug,
        surface: Surface? = nil,
        shape: AnyShape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        overflow: Overflow = .clip,
        @ChildrenBuilder content: () -> [any View]
    ) {
        self.init(frame: frame, surface: surface, shape: shape,
                  padding: padding, alignment: alignment,
                  clip: clip, overflow: overflow, children: content())
    }

    public init(_ style: BoxStyle, children: [any View] = []) {
        self.init(frame: style.frame, surface: style.surface, shape: style.shape,
                  padding: style.padding, alignment: style.alignment,
                  clip: style.clip, overflow: style.overflow, children: children)
    }

    public init(_ style: BoxStyle, @ChildrenBuilder content: () -> [any View]) {
        self.init(frame: style.frame, surface: style.surface, shape: style.shape,
                  padding: style.padding, alignment: style.alignment,
                  clip: style.clip, overflow: style.overflow, children: content())
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        BoxRenderer(view: self)
        #else
        fatalError("Box not yet implemented for this platform")
        #endif
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

    func scrollable(_ config: ScrollConfig = ScrollConfig()) -> Box {
        Box(overflow: .scroll(config)) { self }
    }
}

// MARK: - BoxRole

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
    private weak var boxView: BoxView?
    private var view: Box

    init(view: Box) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let box = newView as? Box, let boxView else { return }
        let old = view
        view = box

        var needsSelfLayout = false
        var needsParentLayout = false
        var needsDisplay = false

        // Frame affects own size (parent re-measures) and child layout
        if old.frame != box.frame {
            boxView.sizing = box.frame
            needsSelfLayout = true
            needsParentLayout = true
        }

        // Padding/alignment/overflow affect child positioning
        if old.padding != box.padding {
            boxView.padding = box.padding
            needsSelfLayout = true
        }
        if old.alignment != box.alignment {
            boxView.alignment = box.alignment
            needsSelfLayout = true
        }
        // Overflow contains non-Equatable scroll state — always apply
        boxView.overflow = box.overflow
        needsSelfLayout = true

        // Shape/surface update the surface sublayer via didSet/layout
        boxView.shape = box.shape
        boxView.surface = box.surface
        needsSelfLayout = true

        if old.clip != box.clip {
            boxView.clip = box.clip
            needsSelfLayout = true
        }

        if needsSelfLayout { boxView.setNeedsLayout() }
        if needsParentLayout { boxView.superview?.setNeedsLayout() }
    }

    func mount() -> PlatformView {
        let bv = BoxView()
        self.boxView = bv
        bv.sizing = view.frame
        bv.shape = view.shape
        bv.surface = view.surface
        bv.clip = view.clip
        bv.padding = view.padding
        bv.alignment = view.alignment
        bv.overflow = view.overflow
        return bv
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - BoxView

/// The backing UIView for Box. Handles surface painting, child layout
/// (alignment-based positioning), frame constraints, shape clipping,
/// and optional scroll overflow.
class BoxView: UIView {
    var shape: AnyShape?
    var surface: Surface? { didSet { surfaceView.surface = surface; layoutSurfaceView() } }
    var clip: Bool = true
    var sizing: Frame = .hug
    var padding: Padding = .zero
    var alignment: Alignment = .center
    var overflow: Overflow = .clip {
        didSet { configureScroll() }
    }

    // Scroll support (lazily created when overflow == .scroll)
    private var scrollView: UIScrollView?
    private var scrollState: ScrollState?

    // Surface painting — separate view that can overflow bounds
    private let surfaceView = SurfaceView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        super.addSubview(surfaceView)
    }

    required init?(coder: NSCoder) { fatalError() }

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
    /// fix → exact value, fill → proposed size, hug → content size + padding.
    /// Children are proposed the size minus padding so they don't overflow.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let innerSize = CGSize(
            width: max(0, size.width - padding.leading - padding.trailing),
            height: max(0, size.height - padding.top - padding.bottom)
        )
        let content = childrenSize(proposing: innerSize)
        let w: CGFloat = switch sizing.width {
        case .fix(let v): v
        case .fill: size.width
        case .hug: content.width + padding.leading + padding.trailing
        }
        let h: CGFloat = switch sizing.height {
        case .fix(let v): v
        case .fill: size.height
        case .hug: content.height + padding.top + padding.bottom
        }
        return CGSize(width: w, height: h)
    }

    /// fix → exact value, otherwise noIntrinsicMetric.
    override var intrinsicContentSize: CGSize {
        let w: CGFloat = switch sizing.width {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        let h: CGFloat = switch sizing.height {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        return CGSize(width: w, height: h)
    }

    /// Max size of children (overlay — all share the same space).
    private func childrenSize(proposing size: CGSize) -> CGSize {
        var maxW: CGFloat = 0, maxH: CGFloat = 0
        for child in contentChildren {
            let s = child.sizeThatFits(size)
            maxW = max(maxW, s.width)
            maxH = max(maxH, s.height)
        }
        return CGSize(width: maxW, height: maxH)
    }

    // MARK: - Frame Constraints

    /// When added to a parent, apply Auto Layout constraints for
    /// this box's own sizing: fix → width/height, fill → pin to parent.
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        // Inside a PassthroughView (ComposedNode wrapper), attach() pins
        // to fill — don't add conflicting constraints.
        guard !(superview is PassthroughView) else { return }
        constrain {
            switch sizing.width {
            case .fix(let w): widthAnchor.equal(w)
            case .fill: leadingAnchor.equal(superview.leadingAnchor); trailingAnchor.equal(superview.trailingAnchor)
            case .hug: break
            }
            switch sizing.height {
            case .fix(let h): heightAnchor.equal(h)
            case .fill: topAnchor.equal(superview.topAnchor); bottomAnchor.equal(superview.bottomAnchor)
            case .hug: break
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutSurfaceView()
        layoutScrollView()
        layoutChildren()
        updateScrollContentSize()
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

    /// Measure a child, respecting fill extents and scroll axis.
    private func resolveChildSize(_ child: UIView, in inset: CGRect) -> CGSize {
        let scrollAxis: Axis? = if case .scroll(let c) = overflow { c.axis } else { nil }
        let isScrolling = scrollView != nil

        // Propose: unlimited on scroll axis, inset size otherwise
        let proposedW: CGFloat = (isScrolling && scrollAxis != .vertical) ? .greatestFiniteMagnitude : inset.width
        let proposedH: CGFloat = (isScrolling && scrollAxis != .horizontal) ? .greatestFiniteMagnitude : inset.height
        var size = child.sizeThatFits(CGSize(width: proposedW, height: proposedH))
        // Fill children expand to fill the inset on their fill axis
        if let boxChild = child as? BoxView {
            if case .fill = boxChild.sizing.width { size.width = inset.width }
            if case .fill = boxChild.sizing.height { size.height = inset.height }
        }

        return size
    }

    /// Compute origin for a child of given size within the inset,
    /// using alignment. When scrolling, only pin to origin on axes
    /// where the child actually overflows the viewport.
    private func alignedOrigin(childSize: CGSize, in inset: CGRect) -> CGPoint {
        let scrollAxis: Axis? = if case .scroll(let c) = overflow { c.axis } else { nil }
        let isScrolling = scrollView != nil

        let fx = (alignment.x + 1) / 2
        let fy = (alignment.y + 1) / 2

        let overflowsH = childSize.width > inset.width
        let overflowsV = childSize.height > inset.height

        let x: CGFloat = (isScrolling && scrollAxis != .vertical && overflowsH)
            ? inset.minX
            : inset.minX + max(0, inset.width - childSize.width) * fx

        let y: CGFloat = (isScrolling && scrollAxis != .horizontal && overflowsV)
            ? inset.minY
            : inset.minY + max(0, inset.height - childSize.height) * fy

        return CGPoint(x: x, y: y)
    }

    /// Apply shape mask for clipping.
    private func applyShapeClip() {
        if clip {
            let resolvedShape: AnyShape = shape ?? RectShape().erased
            let maskLayer = CAShapeLayer()
            maskLayer.path = resolvedShape.path(in: Rect(bounds)).cgPath
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }

    /// The actual content children (through scroll view if scrolling).
    private var contentChildren: [UIView] {
        scrollView?.subviews ?? super.subviews.filter { $0 !== scrollView && $0 !== surfaceView }
    }

    // MARK: - Subview routing

    /// Route addSubview through scroll view when scrolling.
    override func addSubview(_ view: UIView) {
        if let sv = scrollView { sv.addSubview(view) }
        else { super.addSubview(view) }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if let sv = scrollView { sv.insertSubview(view, at: index) }
        else { super.insertSubview(view, at: index + 1) } // +1 to keep surfaceView at 0
    }

    override var subviews: [UIView] {
        scrollView?.subviews ?? super.subviews
    }
}

// MARK: - BoxView + Scroll

extension BoxView: UIScrollViewDelegate {
    /// Create/remove UIScrollView based on overflow setting.
    func configureScroll() {
        if case .scroll(let config) = overflow {
            if scrollView == nil {
                let sv = UIScrollView()
                sv.delegate = self
                super.addSubview(sv)
                scrollView = sv
            }
            let sv = scrollView!
            sv.contentInsetAdjustmentBehavior = config.safeArea ? .automatic : .never
            sv.showsHorizontalScrollIndicator = config.showsIndicators && config.axis != .vertical
            sv.showsVerticalScrollIndicator = config.showsIndicators && config.axis != .horizontal
            sv.bounces = config.bounces
            sv.isPagingEnabled = config.paging
            scrollState = config.state
            config.state?.scrollCommand = { [weak self] offset, animated in
                self?.scrollView?.setContentOffset(CGPoint(x: offset.x, y: offset.y), animated: animated)
            }
        } else {
            scrollView?.removeFromSuperview()
            scrollView = nil
            scrollState = nil
        }
    }

    /// Size scroll view to fill bounds.
    func layoutScrollView() {
        scrollView?.frame = bounds
    }

    /// Update scroll view's contentSize from children frames.
    func updateScrollContentSize() {
        guard let sv = scrollView else { return }
        var contentW: CGFloat = 0, contentH: CGFloat = 0
        for child in sv.subviews {
            contentW = max(contentW, child.frame.maxX + padding.trailing)
            contentH = max(contentH, child.frame.maxY + padding.bottom)
        }
        sv.contentSize = CGSize(width: contentW, height: contentH)
        scrollState?.contentSize = Size(contentW, contentH)
        scrollState?.viewportSize = Size(bounds.width, bounds.height)
    }

    /// Forward scroll offset to ScrollState.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = Vec2(scrollView.contentOffset.x, scrollView.contentOffset.y)
        scrollState?.offset = offset
        scrollState?.onScroll?(offset)
    }
}

// MARK: - DebugOverlay

public extension View {
    func debug(_ color: Color = .red, label: String? = nil) -> DebugOverlay {
        DebugOverlay(child: self, color: Color(platform: color.platformColor), label: label)
    }
}

public struct DebugOverlay: ContainerView {
    public let child: any View
    public let color: Color
    public let label: String?
    public let children: [any View]

    init(child: any View, color: Color, label: String?) {
        self.child = child
        self.color = color
        self.label = label
        self.children = [child]
    }

    public func makeRenderer() -> ContainerRenderer {
        DebugOverlayRenderer(view: self)
    }
}

final class DebugOverlayRenderer: ContainerRenderer {
    private weak var overlayView: DebugOverlayView?
    private var view: DebugOverlay

    init(view: DebugOverlay) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let overlay = newView as? DebugOverlay, let overlayView else { return }
        let old = view
        view = overlay

        if old.color != overlay.color {
            overlayView.debugColor = overlay.color
            overlayView.setNeedsDisplay()
        }
        if old.label != overlay.label {
            overlayView.debugLabel = overlay.label
            overlayView.setNeedsDisplay()
        }
    }

    func mount() -> PlatformView {
        let ov = DebugOverlayView()
        self.overlayView = ov
        ov.debugColor = view.color
        ov.debugLabel = view.label
        return ov
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

final class DebugOverlayView: UIView {
    var debugColor: Color = .red
    var debugLabel: String?
    private let infoLabel = UILabel()
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        clipsToBounds = false

        borderLayer.fillColor = nil
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        infoLabel.font = .systemFont(ofSize: 9, weight: .medium)
        addSubview(infoLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // First content child (not the info label)
        contentChild?.sizeThatFits(size) ?? .zero
    }

    private var contentChild: UIView? {
        subviews.first { $0 !== infoLabel }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentChild?.frame = bounds

        let uiColor = debugColor.platformColor

        // Border
        borderLayer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        borderLayer.strokeColor = uiColor.withAlphaComponent(0.5).cgColor

        // Background
        backgroundColor = uiColor.withAlphaComponent(0.05)

        // Info label below bounds
        let hash = String(format: "%04x", abs(hashValue) % 0xFFFF)
        let name = debugLabel ?? hash
        infoLabel.text = "\(name) (\(Int(frame.origin.x)),\(Int(frame.origin.y))) w:\(Int(bounds.width))/h:\(Int(bounds.height))"
        infoLabel.textColor = uiColor
        infoLabel.sizeToFit()
        infoLabel.frame.origin = CGPoint(x: 2, y: bounds.height + 2)
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
