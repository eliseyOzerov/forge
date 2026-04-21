// MARK: - SafeArea

/// Container that insets content to respect device safe areas.
///
/// Forge doesn't apply safe-area behaviour implicitly — root content is
/// edge-to-edge by default. When a screen wants to avoid the dynamic
/// island / home indicator / notch, it wraps its body in `SafeArea`.
///
///     SafeArea { HomeView() }                          // all edges
///     SafeArea(edges: .vertical) { ... }               // top + bottom
///     SafeArea(edges: [.top]) { ... }                  // top only
///     SafeArea(edges: .all.subtracting(.bottom)) { ... }
public struct SafeArea: ContainerView {
    public let child: any View
    public let edges: Edge.Set
    public var children: [any View] { [child] }

    public init(
        edges: Edge.Set = .all,
        @ChildBuilder _ content: () -> any View
    ) {
        self.child = content()
        self.edges = edges
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        SafeAreaRenderer(edges: edges)
        #else
        fatalError("SafeArea not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class SafeAreaRenderer: ContainerRenderer {
    private weak var safeAreaView: SafeAreaView?
    private var edges: Edge.Set

    init(edges: Edge.Set) {
        self.edges = edges
    }

    func update(from newView: any View) {
        guard let safeArea = newView as? SafeArea, let safeAreaView else { return }
        guard edges != safeArea.edges else { return }
        edges = safeArea.edges
        safeAreaView.edges = edges
        safeAreaView.setNeedsLayout()
    }

    func mount() -> PlatformView {
        let sv = SafeAreaView()
        self.safeAreaView = sv
        sv.edges = edges
        return sv
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

// MARK: - SafeAreaView

class SafeAreaView: UIView {
    var edges: Edge.Set = .all

    override func layoutSubviews() {
        super.layoutSubviews()
        let insets = resolveInsets()
        subviews.first?.frame = bounds.inset(by: insets)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let insets = resolveInsets()
        let availableWidth = size.width - insets.left - insets.right
        let availableHeight = size.height - insets.top - insets.bottom
        let childSize = child.sizeThatFits(CGSize(
            width: max(0, availableWidth),
            height: max(0, availableHeight)
        ))
        return CGSize(
            width: childSize.width + insets.left + insets.right,
            height: childSize.height + insets.top + insets.bottom
        )
    }

    override var intrinsicContentSize: CGSize {
        guard let child = subviews.first else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let intrinsic = child.intrinsicContentSize
        let insets = resolveInsets()
        let width: CGFloat = intrinsic.width == UIView.noIntrinsicMetric
            ? UIView.noIntrinsicMetric
            : intrinsic.width + insets.left + insets.right
        let height: CGFloat = intrinsic.height == UIView.noIntrinsicMetric
            ? UIView.noIntrinsicMetric
            : intrinsic.height + insets.top + insets.bottom
        return CGSize(width: width, height: height)
    }

    private func resolveInsets() -> UIEdgeInsets {
        let s = safeAreaInsets
        return UIEdgeInsets(
            top: edges.hasTop ? s.top : 0,
            left: edges.hasLeading ? s.left : 0,
            bottom: edges.hasBottom ? s.bottom : 0,
            right: edges.hasTrailing ? s.right : 0
        )
    }
}

#endif
