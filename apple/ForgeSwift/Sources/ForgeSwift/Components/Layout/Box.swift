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

/// Visual styling for Box (surface, shape, padding, frame).
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

// MARK: - BoxLayout

/// Independent layout: all children share the same space, each aligned
/// within the padded bounds.
///
/// ## Measurement
///
/// The box first checks its own frame per axis:
/// - **Fixed** — return the fixed size. Children don't affect own size.
/// - **Fill** — return the proposed size (100% of available).
/// - **Hug** — measure all children against the inner bounds
///   (proposed minus padding, clamped to min/max). Own size is the
///   largest child on each axis, plus padding.
///
/// Overflow affects the proposal to children:
/// - **clip / visible** — children proposed inner bounds.
/// - **scroll** — children proposed unlimited on the scroll axis.
/// - **fit** — children proposed inner bounds; sizes clamped after.
///
/// ## Layout
///
/// Each child is positioned independently using alignment:
///
///     fx = (alignment.x + 1) / 2
///     origin.x = padding.leading + (innerWidth - childWidth) * fx
public final class BoxLayout: Layout {
    public var padding: Padding
    public var alignment: Alignment
    public var frame: Frame
    public var overflow: Overflow
    public var slots: [LayoutSlot]

    private var bounds: Size = .zero
    private var inner: Size = .zero

    public init(
        padding: Padding = .zero,
        alignment: Alignment = .center,
        frame: Frame = .hug,
        overflow: Overflow = .clip,
        slots: [LayoutSlot] = []
    ) {
        self.padding = padding
        self.alignment = alignment
        self.frame = frame
        self.overflow = overflow
        self.slots = slots
    }

    // MARK: - Measurable

    public func measure(proposed: Size) -> Size {
                
        let proposedInner = proposeBounds(proposed: bounds)
        
        let inner: Size = slots.reduce(.zero) { result, slot in
            slot.child.measure(proposed: proposedInner)
        }
        
        
        
        return bounds
    }

    // MARK: - Layout

    public func start(_ bounds: Size) {
        self.bounds = bounds
    }

    public func layout() {
        fatalError("TODO")
    }

    // MARK: - Proposal

    /// The size to propose to children given the parent's proposal.
    ///
    /// - **fix** — `fixedValue - padding`. The space is known.
    /// - **hug** — `(proposed - padding).clamped(min, max)`.
    /// - **fill** — `0`. Measure children at zero to find their minimum.
    public func proposeBounds(proposed: Size) -> Size {
        func resolve(_ extent: Extent, _ proposed: Double, _ padding: Double) -> Double {
            let raw: Double = switch extent {
            case .fix(let v): v - padding
            case .hug(let min, let max): (proposed - padding).clamped(min: min, max: max)
            case .fill: 0
            }
            return Swift.max(0, raw)
        }
        return Size(
            resolve(frame.width, proposed.width, padding.horizontal),
            resolve(frame.height, proposed.height, padding.vertical)
        )
    }
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

    func update(from newView: any View) {
        guard let box = newView as? Box, let boxView else { return }
        let old = view
        view = box

        var needsSelfLayout = false
        var needsParentLayout = false

        // Frame affects own size (parent re-measures) and child layout
        if old.frame != box.frame {
            boxView.sizing = box.frame
            needsSelfLayout = true
            needsParentLayout = true
        }

        // Padding/alignment affect child positioning
        if old.padding != box.padding {
            boxView.padding = box.padding
            needsSelfLayout = true
        }
        if old.alignment != box.alignment {
            boxView.alignment = box.alignment
            needsSelfLayout = true
        }
        if old.overflow != box.overflow {
            boxView.overflow = box.overflow
            needsSelfLayout = true
        }

        if old.shape != box.shape {
            boxView.shape = box.shape
            needsSelfLayout = true
        }
        if old.surface != box.surface {
            boxView.surface = box.surface
            needsSelfLayout = true
        }

        if old.clip != box.clip {
            boxView.clip = box.clip
            needsSelfLayout = true
        }

        if needsSelfLayout { boxView.setNeedsLayout() }
        if needsParentLayout { boxView.superview?.setNeedsLayout() }
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
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
    var sizing: Frame = .hug {
        didSet {
            guard sizing != oldValue else { return }
            updateSizingConstraints()
        }
    }
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

    // Auto Layout constraints installed for the current sizing mode
    private var sizingConstraints: [NSLayoutConstraint] = []

    // Shape mask caching — avoid re-creating every layout pass
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
        case .fill:
            sizingConstraints.append(leadingAnchor.equal(superview.leadingAnchor))
            sizingConstraints.append(trailingAnchor.equal(superview.trailingAnchor))
        case .hug: break
        }
        switch sizing.height {
        case .fix(let h): sizingConstraints.append(heightAnchor.equal(h))
        case .fill:
            sizingConstraints.append(topAnchor.equal(superview.topAnchor))
            sizingConstraints.append(bottomAnchor.equal(superview.bottomAnchor))
        case .hug: break
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

    /// The actual content children (through scroll view if scrolling).
    private var contentChildren: [UIView] {
        if let sv = scrollView { return sv.subviews }
        return super.subviews.filter { !isInternalView($0) }
    }

    /// Number of internal (non-content) direct subviews before content children.
    private var internalViewCount: Int {
        var count = 1 // surfaceView is always present
        if scrollView != nil { count += 1 }
        return count
    }

    private func isInternalView(_ view: UIView) -> Bool {
        view === surfaceView || view === scrollView
    }

    // MARK: - Subview routing

    /// Route addSubview through scroll view when scrolling.
    override func addSubview(_ view: UIView) {
        if let sv = scrollView { sv.addSubview(view) }
        else { super.addSubview(view) }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if let sv = scrollView { sv.insertSubview(view, at: index) }
        else { super.insertSubview(view, at: index + internalViewCount) }
    }

    override var subviews: [UIView] {
        if let sv = scrollView { return sv.subviews }
        return super.subviews.filter { !isInternalView($0) }
    }
}

// MARK: - BoxView + Scroll

extension BoxView: UIScrollViewDelegate {
    /// Create/remove UIScrollView based on overflow setting.
    /// Migrates existing content children into/out of the scroll view.
    func configureScroll() {
        if case .scroll(let config) = overflow {
            if scrollView == nil {
                let sv = UIScrollView()
                sv.delegate = self
                // Migrate existing content children into the scroll view
                let existing = super.subviews.filter { !isInternalView($0) }
                super.addSubview(sv)
                for child in existing {
                    child.removeFromSuperview()
                    sv.addSubview(child)
                }
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
        } else if let sv = scrollView {
            // Migrate children back out of the scroll view
            let children = sv.subviews
            sv.removeFromSuperview()
            scrollView = nil
            scrollState = nil
            for child in children {
                super.addSubview(child)
            }
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

/// Debug visualization overlay showing layout boundaries.
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
