// MARK: - SafeArea

/// Consumes safe area padding for the requested edges, insetting its child.
///
/// If an ancestor provides `SafeAreaPadding`, those values are used.
/// Otherwise, reads platform safe area insets directly.
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
///         .safeInset(.top) { NavBar() }
///         .safeInset(.bottom) { TabBar() }
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

/// Insets its child by the resolved safe area padding for the requested edges.
/// Reads provided `SafeAreaPadding` from the node context if available,
/// otherwise falls back to platform `safeAreaInsets`.
class SafeAreaHostView: UIView, InsetsProvider {
    var edges: Edge.Set = .all

    /// What this view inherited from above.
    private var inherited: Padding { findProvidedSafeArea() ?? .from(safeAreaInsets) }

    /// What's left for descendants — consumed edges zeroed out.
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

    /// Walk the Forge node tree to find the nearest provided SafeAreaPadding.
    private func findProvidedSafeArea() -> Padding? {
        // Walk superview chain to find a Provided slot
        var view: UIView? = superview
        while let v = view {
            if let provider = v as? InsetsProvider {
                return provider.insets
            }
            view = v.superview
        }
        return nil
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
    
    var overlay: UIView? { subviews.last }
    var overlaySize: Size { Size(overlay?.sizeThatFits(bounds.size) ?? .zero) }

    var insets: Padding {
        var result = inheritedInsets
        switch edge {
            case .top: result.top += overlaySize.height
            case .bottom: result.bottom += overlaySize.height
            case .leading: result.leading += overlaySize.width
            case .trailing: result.trailing += overlaySize.width
        }
        return result
    }
    
    var inheritedInsets: Padding { findProvidedSafeArea() ?? .from(safeAreaInsets) }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let overlay = overlay else {
            content?.frame = bounds
            return
        }

        switch edge {
        case .top:
            overlay.frame = CGRect(
                x: inheritedInsets.leading,
                y: inheritedInsets.top,
                width: bounds.width,
                height: overlaySize.height
            )
        case .bottom:
            overlay.frame = CGRect(
                x: 0,
                y: bounds.height - overlaySize.height,
                width: bounds.width,
                height: overlaySize.height
            )
        case .leading:
            overlay.frame = CGRect(
                x: 0,
                y: 0,
                width: overlaySize.width,
                height: bounds.height
            )
        case .trailing:
            overlay.frame = CGRect(
                x: bounds.width - overlaySize.width,
                y: 0,
                width: overlaySize.width,
                height: bounds.height
            )
        }

        content?.frame = bounds
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    private func findProvidedSafeArea() -> Padding? {
        var view: UIView? = superview
        while let v = view {
            if let provider = v as? InsetsProvider { return provider.insets }
            view = v.superview
        }
        return nil
    }
}

// MARK: - SafeAreaPaddingProvider

/// Protocol for views that provide safe area padding to descendants.
@MainActor protocol InsetsProvider: AnyObject {
    var insets: Padding { get }
}

#endif
