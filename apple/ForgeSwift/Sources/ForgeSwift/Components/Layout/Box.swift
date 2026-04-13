#if canImport(UIKit)
import UIKit

/// The fundamental layout primitive. A container that paints a Surface,
/// clips to a Shape, and overlays its children (each aligned independently).
///
/// Single child = styled container. Multiple children = overlay (ZStack).
///
/// ```swift
/// Box(
///     frame: .fixed(200, 200),
///     shape: .roundedRect(radius: 12),
///     surface: Surface { $0.color(.white).shadow(blur: 8) },
///     padding: Padding(all: 16)
/// ) {
///     Text("Hello")
/// }
/// ```
// MARK: - BoxStyle

public struct BoxStyle {
    public var frame: Frame
    public var surface: Surface?
    public var shape: Shape?
    public var padding: Padding
    public var alignment: Alignment
    public var clip: Bool
    public var overflow: Overflow

    public init(
        _ frame: Frame = .hug,
        _ surface: Surface? = nil,
        _ shape: Shape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        overflow: Overflow = .clip
    ) {
        self.frame = frame
        self.surface = surface
        self.shape = shape
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.overflow = overflow
    }
}

// MARK: - Box

public struct Box: ContainerView {
    public let frame: Frame
    public let shape: Shape?
    public let surface: Surface?
    public let padding: Padding
    public let alignment: Alignment
    public let clip: Bool
    public let overflow: Overflow
    public let children: [any View]

    public init(
        _ frame: Frame = .hug,
        _ surface: Surface? = nil,
        _ shape: Shape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        overflow: Overflow = .clip,
        children: [any View] = []
    ) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.overflow = overflow
        self.children = children
    }

    public init(
        _ frame: Frame = .hug,
        _ surface: Surface? = nil,
        _ shape: Shape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        overflow: Overflow = .clip,
        @ChildrenBuilder content: () -> [any View]
    ) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.overflow = overflow
        self.children = content()
    }

    public init(_ style: BoxStyle, children: [any View] = []) {
        self.frame = style.frame; self.surface = style.surface; self.shape = style.shape
        self.padding = style.padding; self.alignment = style.alignment
        self.clip = style.clip; self.overflow = style.overflow; self.children = children
    }

    public init(_ style: BoxStyle, @ChildrenBuilder content: () -> [any View]) {
        self.frame = style.frame; self.surface = style.surface; self.shape = style.shape
        self.padding = style.padding; self.alignment = style.alignment
        self.clip = style.clip; self.overflow = style.overflow; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        BoxRenderer(
            frame: frame,
            shape: shape,
            surface: surface,
            padding: padding,
            alignment: alignment,
            clip: clip,
            overflow: overflow
        )
    }
}

// MARK: - Renderer

final class BoxRenderer: ContainerRenderer {
    let frame: Frame
    let shape: Shape?
    let surface: Surface?
    let padding: Padding
    let alignment: Alignment
    let clip: Bool
    let overflow: Overflow

    init(frame: Frame, shape: Shape?, surface: Surface?, padding: Padding, alignment: Alignment, clip: Bool, overflow: Overflow = .clip) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.overflow = overflow
    }

    func mount() -> PlatformView {
        let view = BoxView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? BoxView else { return }
        apply(to: view)
    }

    private func apply(to view: BoxView) {
        view.sizing = frame
        view.shape = shape
        view.surface = surface
        view.clip = clip
        view.padding = padding
        view.alignment = alignment
        view.overflow = overflow
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
    var shape: Shape?
    var surface: Surface?
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Drawing

    /// Paint the surface behind children.
    override func draw(_ rect: CGRect) {
        guard let surface = surface, let ctx = UIGraphicsGetCurrentContext() else { return }
        let resolvedShape = shape ?? .rect()
        SurfaceRenderer(surface: surface, shape: resolvedShape, bounds: bounds).render(in: ctx)
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
        // Inside a ProxyView (ComposedNode wrapper), attach() pins
        // to fill — don't add conflicting constraints.
        guard !(superview is ProxyView) else { return }
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
        if clip, let shape = shape {
            let maskLayer = CAShapeLayer()
            maskLayer.path = shape.resolve(in: bounds).cgPath
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }

    /// The actual content children (through scroll view if scrolling).
    private var contentChildren: [UIView] {
        scrollView?.subviews ?? super.subviews.filter { $0 !== scrollView }
    }

    // MARK: - Subview routing

    /// Route addSubview through scroll view when scrolling.
    override func addSubview(_ view: UIView) {
        if let sv = scrollView { sv.addSubview(view) }
        else { super.addSubview(view) }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if let sv = scrollView { sv.insertSubview(view, at: index) }
        else { super.insertSubview(view, at: index) }
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
    
    func aligned(_ alignment: Alignment) -> Box {
        Box(.fill, alignment: alignment) { self }
    }
    
    func framed(_ frame: Frame) -> Box {
        Box(frame) { self }
    }
    
    func scrollable(_ config: ScrollConfig = ScrollConfig()) -> Box {
        Box(overflow: .scroll(config)) { self }
    }

    func debug(_ color: UIColor = .red, label: String? = nil) -> DebugOverlay {
        DebugOverlay(child: self, color: Color(platform: color), label: label)
    }
}

// MARK: - DebugOverlay

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
        DebugOverlayRenderer(color: color, label: label)
    }
}

final class DebugOverlayRenderer: ContainerRenderer {
    let color: Color
    let label: String?

    init(color: Color, label: String?) {
        self.color = color; self.label = label
    }

    func mount() -> PlatformView {
        let view = DebugOverlayView()
        view.debugColor = color
        view.debugLabel = label
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? DebugOverlayView else { return }
        view.debugColor = color
        view.debugLabel = label
        view.setNeedsDisplay()
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

#endif
