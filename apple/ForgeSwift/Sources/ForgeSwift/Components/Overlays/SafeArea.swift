// MARK: - SafeArea

/// Consumes safe area padding for the requested edges, insetting its child.
/// Walks the superview chain for an `InsetsProvider`, falls back to platform
/// `safeAreaInsets`. Re-provides with consumed edges zeroed so descendants
/// don't double-apply.
///
///     SafeArea { content }              // all edges
///     SafeArea(edges: .top) { content } // top only
public struct SafeArea: ProxyView {
    public let child: any View
    public let edges: Edge.Set

    public init(edges: Edge.Set = .all, @ChildBuilder _ content: () -> any View) {
        self.edges = edges
        self.child = content()
    }

    public func makeRenderer() -> ProxyRenderer {
        #if canImport(UIKit)
        SafeAreaRenderer(edges: edges)
        #else
        fatalError("SafeArea not yet implemented for this platform")
        #endif
    }
}

// MARK: - SafeInset

/// Overlays a view at an edge and adds its measured size to the safe area
/// for descendants. The overlay renders on top of the child, edge-to-edge.
///
///     content
///         .safeArea()
///         .safeInset(.bottom) { TabBar() }
///         .safeInset(.top) { NavBar() }
public struct SafeInset: ContainerView {
    public let edge: Edge
    public let overlay: any View
    public let child: any View
    public var children: [any View] { [child, overlay] }

    public init(
        _ edge: Edge = .top,
        @ChildBuilder overlay: () -> any View,
        @ChildBuilder content: () -> any View
    ) {
        self.edge = edge
        self.overlay = overlay()
        self.child = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        SafeInsetRenderer(edge: edge)
        #else
        fatalError("SafeInset not yet implemented for this platform")
        #endif
    }
}

// MARK: - View Extensions

public extension View {
    /// Inset this view by the current safe area on the given edges.
    func safeArea(edges: Edge.Set = .all) -> SafeArea {
        SafeArea(edges: edges) { self }
    }

    /// Overlay a view at an edge and add its size to the safe area for descendants.
    func safeInset(_ edge: Edge, @ChildBuilder overlay: () -> any View) -> SafeInset {
        SafeInset(edge, overlay: overlay) { self }
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

// MARK: - SafeAreaRenderer

final class SafeAreaRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var hostView: SafeAreaHostView?
    private var edges: Edge.Set

    init(edges: Edge.Set) {
        self.edges = edges
    }

    func mount() -> PlatformView {
        let view = SafeAreaHostView()
        self.hostView = view
        view.edges = edges
        return view
    }

    func update(from newView: any View) {
        guard let sa = newView as? SafeArea, let hostView else { return }
        guard edges != sa.edges else { return }
        edges = sa.edges
        hostView.edges = edges
        hostView.setNeedsLayout()
    }
}

/// Consumes safe area insets for requested edges, re-provides the remainder.
class SafeAreaHostView: UIView, InsetsProvider {
    var edges: Edge.Set = .all

    /// Inherited insets from the nearest provider, or platform fallback.
    private var inherited: Padding { findInsetsProvider() ?? .from(safeAreaInsets) }

    /// What's left for descendants — consumed edges zeroed.
    var insets: Padding { inherited.filter(by: edges.inverse) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let consumed = inherited.filter(by: edges)
        subviews.first?.frame = bounds.inset(by: consumed.uiEdgeInsets)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }
}

// MARK: - SafeInsetRenderer

final class SafeInsetRenderer: ContainerRenderer {
    private weak var containerView: SafeInsetHostView?
    private var edge: Edge

    init(edge: Edge) {
        self.edge = edge
    }

    func mount() -> PlatformView {
        let view = SafeInsetHostView()
        self.containerView = view
        view.edge = edge
        return view
    }

    func update(from newView: any View) {
        guard let inset = newView as? SafeInset, let containerView else { return }
        guard edge != inset.edge else { return }
        edge = inset.edge
        containerView.edge = edge
        containerView.setNeedsLayout()
    }
}

/// Overlays content at an edge and provides updated safe area padding downstream.
final class SafeInsetHostView: UIView, InsetsProvider {
    var edge: Edge = .top

    var content: UIView? { subviews.first }
    var overlay: UIView? { subviews.count >= 2 ? subviews[1] : nil }
    var overlaySize: Size { Size(overlay?.sizeThatFits(bounds.size) ?? .zero) }

    /// Inherited + overlay contribution.
    var insets: Padding {
        var result = findInsetsProvider() ?? .from(safeAreaInsets)
        switch edge {
        case .top: result.top += overlaySize.height
        case .bottom: result.bottom += overlaySize.height
        case .leading: result.leading += overlaySize.width
        case .trailing: result.trailing += overlaySize.width
        }
        return result
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let overlay else {
            content?.frame = bounds
            return
        }

        let inherited = findInsetsProvider() ?? .from(safeAreaInsets)
        let oSize = overlaySize

        switch edge {
        case .top:
            overlay.frame = CGRect(x: inherited.leading, y: inherited.top,
                                   width: bounds.width - inherited.leading - inherited.trailing, height: oSize.height)
        case .bottom:
            overlay.frame = CGRect(x: inherited.leading, y: bounds.height - inherited.bottom - oSize.height,
                                   width: bounds.width - inherited.leading - inherited.trailing, height: oSize.height)
        case .leading:
            overlay.frame = CGRect(x: inherited.leading, y: inherited.top,
                                   width: oSize.width, height: bounds.height - inherited.top - inherited.bottom)
        case .trailing:
            overlay.frame = CGRect(x: bounds.width - inherited.trailing - oSize.width, y: inherited.top,
                                   width: oSize.width, height: bounds.height - inherited.top - inherited.bottom)
        }

        content?.frame = bounds
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        content?.sizeThatFits(size) ?? .zero
    }
}

// MARK: - InsetsProvider

/// Protocol for views that provide safe area insets to descendants via superview walk.
@MainActor protocol InsetsProvider: AnyObject {
    var insets: Padding { get }
}

/// Walk the superview chain to find the nearest InsetsProvider.
extension UIView {
    func findInsetsProvider() -> Padding? {
        var view: UIView? = superview
        while let v = view {
            if let provider = v as? InsetsProvider { return provider.insets }
            view = v.superview
        }
        return nil
    }
}

#endif
