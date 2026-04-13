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
        view.boxFrame = frame
        view.boxShape = shape
        view.boxSurface = surface
        view.boxClip = clip
        view.boxPadding = padding
        view.boxAlignment = alignment
        view.boxOverflow = overflow
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

final class BoxView: UIView, UIScrollViewDelegate {
    var boxShape: Shape?
    var boxSurface: Surface?
    var boxClip: Bool = true
    var boxFrame: Frame = .hug
    var boxPadding: Padding = .zero
    var boxAlignment: Alignment = .center
    var boxOverflow: Overflow = .clip {
        didSet { configureScrollIfNeeded() }
    }

    private var scrollView: UIScrollView?
    private var scrollState: ScrollState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configureScrollIfNeeded() {
        if case .scroll(let config) = boxOverflow {
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

    override func addSubview(_ view: UIView) {
        if let sv = scrollView {
            sv.addSubview(view)
        } else {
            super.addSubview(view)
        }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if let sv = scrollView {
            sv.insertSubview(view, at: index)
        } else {
            super.insertSubview(view, at: index)
        }
    }

    override var subviews: [UIView] {
        scrollView?.subviews ?? super.subviews
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = Vec2(scrollView.contentOffset.x, scrollView.contentOffset.y)
        scrollState?.offset = offset
        scrollState?.onScroll?(offset)
    }

    override func draw(_ rect: CGRect) {
        guard let surface = boxSurface, let ctx = UIGraphicsGetCurrentContext() else { return }
        let resolvedShape = boxShape ?? .rect()
        let renderer = SurfaceRenderer(surface: surface, shape: resolvedShape, bounds: bounds)
        renderer.render(in: ctx)
    }

    override var intrinsicContentSize: CGSize {
        let w: CGFloat = switch boxFrame.width {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        let h: CGFloat = switch boxFrame.height {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        return CGSize(width: w, height: h)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let content = childrenSize(proposing: size)
        let w: CGFloat = switch boxFrame.width {
        case .fix(let v): v
        case .fill, .hug: content.width + boxPadding.leading + boxPadding.trailing
        }
        let h: CGFloat = switch boxFrame.height {
        case .fix(let v): v
        case .fill, .hug: content.height + boxPadding.top + boxPadding.bottom
        }
        return CGSize(width: w, height: h)
    }

    private func childrenSize(proposing size: CGSize) -> CGSize {
        var maxW: CGFloat = 0, maxH: CGFloat = 0
        for child in subviews {
            let s = child.sizeThatFits(size)
            maxW = max(maxW, s.width)
            maxH = max(maxH, s.height)
        }
        return CGSize(width: maxW, height: maxH)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        applyFrameConstraints(in: superview)
    }

    private func applyFrameConstraints(in parent: UIView) {
        constrain {
            switch boxFrame.width {
            case .fix(let w): widthAnchor.equal(w)
            case .fill: leadingAnchor.equal(parent.leadingAnchor); trailingAnchor.equal(parent.trailingAnchor)
            case .hug: break
            }

            switch boxFrame.height {
            case .fix(let h): heightAnchor.equal(h)
            case .fill: topAnchor.equal(parent.topAnchor); bottomAnchor.equal(parent.bottomAnchor)
            case .hug: break
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Position scroll view to fill bounds
        scrollView?.frame = bounds

        let inset = CGRect(
            x: boxPadding.leading,
            y: boxPadding.top,
            width: bounds.width - boxPadding.leading - boxPadding.trailing,
            height: bounds.height - boxPadding.top - boxPadding.bottom
        )

        let scrollAxis: Axis? = if case .scroll(let config) = boxOverflow { config.axis } else { nil }
        let isScrolling = scrollView != nil
        let children = isScrolling ? (scrollView?.subviews ?? []) : subviews.filter { $0 !== scrollView }

        for child in children {
            // For scroll: propose unlimited size on scroll axis
            let proposedW: CGFloat = (isScrolling && scrollAxis != .vertical) ? .greatestFiniteMagnitude : inset.width
            let proposedH: CGFloat = (isScrolling && scrollAxis != .horizontal) ? .greatestFiniteMagnitude : inset.height
            let childSize = child.sizeThatFits(CGSize(width: proposedW, height: proposedH))

            let fx = (boxAlignment.x + 1) / 2
            let fy = (boxAlignment.y + 1) / 2

            // On scroll axis: position at 0 (scrolling handles offset). On non-scroll axis: align.
            let x: CGFloat
            let y: CGFloat
            if isScrolling && scrollAxis != .vertical {
                x = inset.minX  // horizontal scrolls from leading
            } else {
                x = inset.minX + max(0, inset.width - childSize.width) * fx
            }
            if isScrolling && scrollAxis != .horizontal {
                y = inset.minY  // vertical scrolls from top
            } else {
                y = inset.minY + max(0, inset.height - childSize.height) * fy
            }

            child.frame = CGRect(x: x, y: y, width: childSize.width, height: childSize.height)
        }

        // Update scroll view content size
        if let sv = scrollView {
            var contentW: CGFloat = 0, contentH: CGFloat = 0
            for child in sv.subviews {
                contentW = max(contentW, child.frame.maxX + boxPadding.trailing)
                contentH = max(contentH, child.frame.maxY + boxPadding.bottom)
            }
            sv.contentSize = CGSize(width: contentW, height: contentH)
            scrollState?.contentSize = Size(contentW, contentH)
            scrollState?.viewportSize = Size(bounds.width, bounds.height)
        }

        // Clip to shape
        if boxClip, let shape = boxShape {
            let maskLayer = CAShapeLayer()
            maskLayer.path = shape.resolve(in: bounds).cgPath
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }
}

// MARK: - View Extensions

public extension View {
    func centered() -> Box {
        Box(.fill, alignment: .center, children: [self])
    }

    func padded(_ padding: Padding) -> Box {
        Box(.fill, padding: padding, alignment: .topLeft, children: [self])
    }

    func padded(_ all: Double) -> Box {
        Box(.fill, padding: Padding(all: all), alignment: .topLeft, children: [self])
    }

    func debug(_ color: UIColor = .red) -> Box {
        let c = Color(platform: color)
        return Box(.hug, .color(c.withAlpha(0.1)).border(c, width: 1), children: [self])
    }
}

#endif
