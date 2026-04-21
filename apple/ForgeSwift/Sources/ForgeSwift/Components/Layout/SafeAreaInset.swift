// MARK: - SafeAreaInset

/// Container that overlays content at an edge and adds its measured size
/// to the safe area for the main child.
///
/// The overlay sits on top of the content (z-order) and is pinned to
/// the specified edge. Its size along that edge's axis is reported as
/// additional safe-area insets so that any `SafeArea` view inside the
/// content subtree automatically accounts for the overlay.
///
///     SafeAreaInset(edge: .top, overlay: { NavigationBar(...) }) {
///         ScrollableContent()
///     }
public struct SafeAreaInset: ContainerView {
    public let edge: Edge
    public let overlay: any View
    public let child: any View
    public var children: [any View] { [child, overlay] }

    public init(
        edge: Edge = .top,
        @ChildBuilder overlay: () -> any View,
        @ChildBuilder content: () -> any View
    ) {
        self.edge = edge
        self.overlay = overlay()
        self.child = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        SafeAreaInsetRenderer(edge: edge)
        #else
        fatalError("SafeAreaInset not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class SafeAreaInsetRenderer: ContainerRenderer {
    private weak var containerView: SafeAreaInsetView?
    private var edge: Edge

    init(edge: Edge) {
        self.edge = edge
    }

    func update(from newView: any View) {
        guard let inset = newView as? SafeAreaInset, let containerView else { return }
        guard edge != inset.edge else { return }
        edge = inset.edge
        containerView.edge = edge
        containerView.setNeedsLayout()
    }

    func mount() -> PlatformView {
        let view = SafeAreaInsetView()
        self.containerView = view
        view.edge = edge
        return view
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
        container.setNeedsLayout()
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
        container.setNeedsLayout()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
        container.setNeedsLayout()
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - SafeAreaInsetView

/// Platform view that overlays a child at one edge and provides its
/// measured size as additional safe-area insets for the content child.
final class SafeAreaInsetView: UIView, SafeAreaAdjustmentProvider {
    var edge: Edge = .top
    private(set) var safeAreaAdjustment: UIEdgeInsets = .zero

    override func layoutSubviews() {
        super.layoutSubviews()

        // children[0] = content (index 0), children[1] = overlay (index 1)
        guard subviews.count >= 2 else {
            subviews.first?.frame = bounds
            return
        }

        let content = subviews[0]
        let overlay = subviews[1]

        // Measure the overlay
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

        // Content fills the entire bounds (overlay pattern)
        content.frame = bounds

        // Update safe-area adjustment based on overlay measurement
        let newAdjustment: UIEdgeInsets
        switch edge {
        case .top:
            newAdjustment = UIEdgeInsets(top: overlaySize.height, left: 0, bottom: 0, right: 0)
        case .bottom:
            newAdjustment = UIEdgeInsets(top: 0, left: 0, bottom: overlaySize.height, right: 0)
        case .leading:
            newAdjustment = UIEdgeInsets(top: 0, left: overlaySize.width, bottom: 0, right: 0)
        case .trailing:
            newAdjustment = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: overlaySize.width)
        }

        if safeAreaAdjustment != newAdjustment {
            safeAreaAdjustment = newAdjustment
            content.setNeedsLayout()
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let content = subviews.first else { return .zero }
        return content.sizeThatFits(size)
    }

    override var intrinsicContentSize: CGSize {
        guard let content = subviews.first else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        return content.intrinsicContentSize
    }
}

#endif
