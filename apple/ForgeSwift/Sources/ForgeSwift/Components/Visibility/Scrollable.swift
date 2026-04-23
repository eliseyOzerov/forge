/// Scrollable wrapper that enables content to scroll along one or both axes.
///
/// ```swift
/// Scroll(.vertical) {
///     Column { ... }
/// }
/// ```
///
/// See `ScrollConfig` for axis, indicators, bounce, and paging options.
/// See `ScrollState` for programmatic scroll control.
public struct Scrollable: ProxyView {
    public let child: any View
    public var config: ScrollConfig

    public init(_ config: ScrollConfig = ScrollConfig(), @ChildBuilder content: () -> any View) {
        self.child = content()
        self.config = config
    }

    public init(_ axis: Axis? = nil, @ChildBuilder content: () -> any View) {
        self.child = content()
        self.config = ScrollConfig(axis: axis)
    }

    public func makeRenderer() -> ProxyRenderer {
        #if canImport(UIKit)
        ScrollRenderer(view: self)
        #else
        fatalError("Scroll not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class ScrollRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var hostView: ScrollHostView?
    private var view: Scrollable

    init(view: Scrollable) {
        self.view = view
    }

    func mount() -> PlatformView {
        let host = ScrollHostView()
        self.hostView = host
        host.configure(view.config)
        return host
    }

    func update(from newView: any View) {
        guard let scroll = newView as? Scrollable, let host = hostView else { return }
        let old = view
        view = scroll
        if old.config != scroll.config {
            host.configure(scroll.config)
        }
    }
}

// MARK: - ScrollHostView

/// Hosts a UIScrollView and routes child views into it.
/// Measures the child with unlimited size on the scroll axis
/// and sets contentSize from the child's resulting frame.
final class ScrollHostView: UIView {
    private let scrollView = UIScrollView()
    private var scrollAxis: Axis?
    private var scrollState: ScrollState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
        scrollView.delegate = self
        super.addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ config: ScrollConfig) {
        scrollAxis = config.axis
        scrollView.contentInsetAdjustmentBehavior = config.safeArea ? .automatic : .never
        scrollView.showsHorizontalScrollIndicator = config.showsIndicators && config.axis != .vertical
        scrollView.showsVerticalScrollIndicator = config.showsIndicators && config.axis != .horizontal
        scrollView.bounces = config.bounces
        scrollView.isPagingEnabled = config.paging
        scrollState = config.state
        config.state?.scrollCommand = { [weak self] offset, animated in
            self?.scrollView.setContentOffset(CGPoint(x: offset.x, y: offset.y), animated: animated)
        }
        setNeedsLayout()
    }

    // MARK: - Subview Routing

    override func addSubview(_ view: UIView) {
        if view === scrollView { super.addSubview(view) }
        else { scrollView.addSubview(view) }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if view === scrollView { super.insertSubview(view, at: index) }
        else { scrollView.insertSubview(view, at: index) }
    }

    override var subviews: [UIView] {
        scrollView.subviews
    }

    // MARK: - Sizing

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let child = scrollView.subviews.first else { return .zero }
        let childSize = child.sizeThatFits(size)
        let bounces = scrollView.bounces
        switch scrollAxis {
        case .vertical:
            let h = bounces ? size.height : min(childSize.height, size.height)
            return CGSize(width: childSize.width, height: h)
        case .horizontal:
            let w = bounces ? size.width : min(childSize.width, size.width)
            return CGSize(width: w, height: childSize.height)
        case nil:
            let w = bounces ? size.width : min(childSize.width, size.width)
            let h = bounces ? size.height : min(childSize.height, size.height)
            return CGSize(width: w, height: h)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        guard let child = scrollView.subviews.first else { return }

        let proposedW: CGFloat = (scrollAxis != .vertical) ? .greatestFiniteMagnitude : bounds.width
        let proposedH: CGFloat = (scrollAxis != .horizontal) ? .greatestFiniteMagnitude : bounds.height
        let childSize = child.sizeThatFits(CGSize(width: proposedW, height: proposedH))

        child.frame = CGRect(origin: .zero, size: childSize)

        scrollView.contentSize = childSize
        scrollState?.contentSize = Size(childSize.width, childSize.height)
        scrollState?.viewportSize = Size(bounds.width, bounds.height)
    }
}

// MARK: - ScrollHostView + Delegate

extension ScrollHostView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = Vec2(scrollView.contentOffset.x, scrollView.contentOffset.y)
        scrollState?.offset = offset
        scrollState?.onScroll?(offset)
    }
}

#endif
