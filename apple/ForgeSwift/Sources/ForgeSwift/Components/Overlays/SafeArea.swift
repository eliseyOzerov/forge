// MARK: - SafeAreaPadding

/// Wrapper around `Padding` to give safe area its own type in the Provided system.
/// Descendants read it via `context.tryRead(SafeAreaPadding.self)`.
public struct SafeAreaPadding {
    public var padding: Padding

    public init(_ padding: Padding = .zero) {
        self.padding = padding
    }
}

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
class SafeAreaHostView: UIView {
    var edges: Edge.Set = .all

    override func layoutSubviews() {
        super.layoutSubviews()
        let insets = resolvedInsets()
        subviews.first?.frame = bounds.inset(by: insets)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let insets = resolvedInsets()
        let available = CGSize(
            width: max(0, size.width - insets.left - insets.right),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        let childSize = child.sizeThatFits(available)
        return CGSize(
            width: childSize.width + insets.left + insets.right,
            height: childSize.height + insets.top + insets.bottom
        )
    }

    /// Resolve insets: use provided safe area if available, fall back to platform.
    private func resolvedInsets() -> UIEdgeInsets {
        let provided = findProvidedSafeArea()
        let platform = safeAreaInsets

        // For each edge: use provided if available (non-zero), otherwise platform
        let top = edges.hasTop ? (provided?.padding.top ?? platform.top) : 0
        let bottom = edges.hasBottom ? (provided?.padding.bottom ?? platform.bottom) : 0
        let leading = edges.hasLeading ? (provided?.padding.leading ?? platform.left) : 0
        let trailing = edges.hasTrailing ? (provided?.padding.trailing ?? platform.right) : 0
        return UIEdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)
    }

    /// Walk the Forge node tree to find the nearest provided SafeAreaPadding.
    private func findProvidedSafeArea() -> SafeAreaPadding? {
        // Walk superview chain to find a Provided slot
        var view: UIView? = superview
        while let v = view {
            if let provider = v as? SafeAreaPaddingProvider {
                return provider.safeAreaPadding
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
final class SafeInsetHostView: UIView, SafeAreaPaddingProvider {
    var edge: Edge = .top
    private(set) var safeAreaPadding: SafeAreaPadding = SafeAreaPadding()

    override func layoutSubviews() {
        super.layoutSubviews()

        // children[0] = content, children[1] = overlay
        guard subviews.count >= 2 else {
            subviews.first?.frame = bounds
            return
        }

        let content = subviews[0]
        let overlay = subviews[1]

        let overlaySize = overlay.sizeThatFits(bounds.size)

        // Position overlay at the specified edge
        switch edge {
        case .top:
            overlay.frame = CGRect(x: 0, y: 0, width: bounds.width, height: overlaySize.height)
        case .bottom:
            overlay.frame = CGRect(x: 0, y: bounds.height - overlaySize.height,
                                   width: bounds.width, height: overlaySize.height)
        case .leading:
            overlay.frame = CGRect(x: 0, y: 0, width: overlaySize.width, height: bounds.height)
        case .trailing:
            overlay.frame = CGRect(x: bounds.width - overlaySize.width, y: 0,
                                   width: overlaySize.width, height: bounds.height)
        }

        // Content fills entire bounds
        content.frame = bounds

        // Resolve current safe area and add overlay size
        let inherited = resolveInherited()
        var updated = inherited
        switch edge {
        case .top: updated.padding.top += overlaySize.height
        case .bottom: updated.padding.bottom += overlaySize.height
        case .leading: updated.padding.leading += overlaySize.width
        case .trailing: updated.padding.trailing += overlaySize.width
        }

        if safeAreaPadding.padding != updated.padding {
            safeAreaPadding = updated
            content.setNeedsLayout()
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    /// Resolve the inherited safe area: walk up for a provider, fall back to platform.
    private func resolveInherited() -> SafeAreaPadding {
        var view: UIView? = superview
        while let v = view {
            if let provider = v as? SafeAreaPaddingProvider {
                return provider.safeAreaPadding
            }
            view = v.superview
        }
        // Fall back to platform insets
        let s = safeAreaInsets
        return SafeAreaPadding(Padding(top: s.top, bottom: s.bottom, leading: s.left, trailing: s.right))
    }
}

// MARK: - SafeAreaPaddingProvider

/// Protocol for views that provide safe area padding to descendants.
@MainActor protocol SafeAreaPaddingProvider: AnyObject {
    var safeAreaPadding: SafeAreaPadding { get }
}

#endif
