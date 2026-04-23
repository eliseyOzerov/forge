// MARK: - Scrollable

/// Scrollable wrapper that enables content to scroll along one axis.
///
/// Use `.ref()` to access the `ScrollableModel` for programmatic scroll
/// control and observable state.
///
/// ```swift
/// @Ref<Scrollable> var scroll
///
/// Scrollable(.vertical) { Column { ... } }
///     .ref(scroll)
///
/// scroll.model?.scrollToTop()
/// ```
public struct Scrollable: ModelView {
    public let child: any View
    public var style: ScrollableStyle

    public init(_ style: ScrollableStyle = ScrollableStyle(), @ChildBuilder content: () -> any View) {
        self.child = content()
        self.style = style
    }

    public init(_ axis: Axis = .vertical, @ChildBuilder content: () -> any View) {
        self.child = content()
        self.style = ScrollableStyle(axis: axis)
    }

    public func model(context: ViewContext) -> ScrollableModel { ScrollableModel(context: context) }
    public func builder(model: ScrollableModel) -> ScrollableBuilder { ScrollableBuilder(model: model) }
}

// MARK: - ScrollableStyle

/// Visual and behavioral configuration for a Scrollable container.
@Init @Copy
public struct ScrollableStyle: Sendable, Equatable {
    public var axis: Axis = .vertical
    public var bounces: Bool = true
    public var enabled: Bool = true
    public var scrollbar: Bool = false
    public var safeArea: Edge.Set = .all
    public var padding: Padding = .zero
    @Snap public var keyboardDismiss: KeyboardDismiss = .onDrag
}

/// Keyboard dismissal behavior during scrolling.
public enum KeyboardDismiss: Sendable, Equatable {
    case none
    case onDrag
    case interactive
}

// MARK: - ScrollableModel

/// Model for a Scrollable view. Provides observable state and programmatic control.
public final class ScrollableModel: ViewModel<Scrollable> {
    /// Current scroll offset.
    public let offset = Observable(Vec2.zero)
    /// Current interaction state (includes `.scrolling` when actively scrolling).
    public let state = Observable(State.idle)
    /// Content size of the scrollable area.
    public internal(set) var content: Size = .zero

    /// Scroll to a specific offset.
    public func scrollTo(_ offset: Vec2, animated: Bool = true) {
        scrollCommand?(offset, animated)
    }

    /// Scroll to the top (vertical) or leading edge (horizontal).
    public func scrollToTop(animated: Bool = true) {
        scrollTo(Vec2(offset.value.x, 0), animated: animated)
    }

    /// Scroll to the bottom (vertical) or trailing edge (horizontal).
    public func scrollToBottom(animated: Bool = true) {
        let maxY = max(0, content.height - viewportSize.height)
        scrollTo(Vec2(offset.value.x, maxY), animated: animated)
    }

    // Internal wiring — set by the host view
    var scrollCommand: ((Vec2, Bool) -> Void)?
    var viewportSize: Size = .zero
}

// MARK: - ScrollableBuilder

public final class ScrollableBuilder: ViewBuilder<ScrollableModel> {
    public override func build(context: ViewContext) -> any View {
        ScrollableHost(model: model, style: model.view.style, child: model.view.child)
    }
}

// MARK: - ScrollableHost

/// Internal proxy view that creates the UIScrollView and wires it to the model.
struct ScrollableHost: ProxyView {
    let model: ScrollableModel
    let style: ScrollableStyle
    let child: any View

    func makeRenderer() -> ProxyRenderer {
        #if canImport(UIKit)
        ScrollableRenderer(model: model, style: style)
        #else
        fatalError("Scrollable not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

final class ScrollableRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var hostView: ScrollableHostView?
    private var model: ScrollableModel
    private var style: ScrollableStyle

    init(model: ScrollableModel, style: ScrollableStyle) {
        self.model = model
        self.style = style
    }

    func mount() -> PlatformView {
        let host = ScrollableHostView()
        self.hostView = host
        host.model = model
        host.configure(style)
        return host
    }

    func update(from newView: any View) {
        guard let host = newView as? ScrollableHost, let hostView else { return }
        let newStyle = host.style
        model = host.model
        hostView.model = model
        if style != newStyle {
            style = newStyle
            hostView.configure(newStyle)
        }
    }
}

// MARK: - ScrollableHostView

/// Hosts a UIScrollView and routes child views into it.
final class ScrollableHostView: UIView {
    private let scrollView = UIScrollView()
    private var axis: Axis = .vertical
    private var bounces: Bool = true
    weak var model: ScrollableModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
        scrollView.delegate = self
        super.addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ style: ScrollableStyle) {
        axis = style.axis
        bounces = style.bounces
        scrollView.isScrollEnabled = style.enabled
        scrollView.bounces = style.bounces
        scrollView.showsHorizontalScrollIndicator = style.scrollbar && style.axis == .horizontal
        scrollView.showsVerticalScrollIndicator = style.scrollbar && style.axis == .vertical

        // Safe area
        if style.safeArea.isEmpty {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            scrollView.contentInsetAdjustmentBehavior = .automatic
        }

        // Padding → content inset
        scrollView.contentInset = UIEdgeInsets(
            top: style.padding.top,
            left: style.padding.leading,
            bottom: style.padding.bottom,
            right: style.padding.trailing
        )

        // Keyboard dismiss
        switch style.keyboardDismiss {
        case .none: scrollView.keyboardDismissMode = .none
        case .onDrag: scrollView.keyboardDismissMode = .onDrag
        case .interactive: scrollView.keyboardDismissMode = .interactive
        }

        // Wire scroll command
        model?.scrollCommand = { [weak self] offset, animated in
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
        switch axis {
        case .vertical:
            let h = bounces ? size.height : min(childSize.height, size.height)
            return CGSize(width: childSize.width, height: h)
        case .horizontal:
            let w = bounces ? size.width : min(childSize.width, size.width)
            return CGSize(width: w, height: childSize.height)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds

        guard let child = scrollView.subviews.first else { return }

        let proposedW: CGFloat = axis == .horizontal ? .greatestFiniteMagnitude : bounds.width
        let proposedH: CGFloat = axis == .vertical ? .greatestFiniteMagnitude : bounds.height
        let childSize = child.sizeThatFits(CGSize(width: proposedW, height: proposedH))

        child.frame = CGRect(origin: .zero, size: childSize)
        scrollView.contentSize = childSize

        model?.content = Size(childSize)
        model?.viewportSize = Size(bounds.size)
    }
}

// MARK: - UIScrollViewDelegate

extension ScrollableHostView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        model?.offset.value = Vec2(scrollView.contentOffset)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        model?.state.value.insert(.scrolling)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { model?.state.value.remove(.scrolling) }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        model?.state.value.remove(.scrolling)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        model?.state.value.remove(.scrolling)
    }
}

#endif
