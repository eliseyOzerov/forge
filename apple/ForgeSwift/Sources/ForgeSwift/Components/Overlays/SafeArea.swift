// MARK: - SafeAreaPadding

/// Provided type for safe area insets. Wraps `Padding` to give it a
/// distinct identity in the Provided system.
public struct SafeAreaPadding: Equatable {
    public var padding: Padding
    public init(_ padding: Padding = .zero) { self.padding = padding }
}

public extension ViewContext {
    /// Read the current safe area padding from the nearest provider.
    var safeArea: Padding { tryWatch(SafeAreaPadding.self)?.padding ?? .zero }
}

// MARK: - SafeArea

/// Consumes safe area padding for the requested edges, insetting its child.
/// Reads `SafeAreaPadding` from context and re-provides with consumed edges zeroed.
///
///     SafeArea { content }              // all edges
///     SafeArea(edges: .top) { content } // top only
public struct SafeArea: BuiltView {
    public let child: any View
    public let edges: Edge.Set

    public init(edges: Edge.Set = .all, @ChildBuilder _ content: () -> any View) {
        self.edges = edges
        self.child = content()
    }

    public func build(context: ViewContext) -> any View {
        let insets = context.safeArea
        let consumed = insets.filter(by: edges)
        let remaining = SafeAreaPadding(insets.filter(by: edges.inverse))
        return Provided(remaining) {
            Box(padding: consumed) { child }
        }
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
