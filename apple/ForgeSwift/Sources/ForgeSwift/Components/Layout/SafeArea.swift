//
//  SafeArea.swift
//  ForgeSwift
//
//  A layout wrapper that insets its child by the platform's safe-area
//  insets. Forge doesn't apply safe-area behaviour implicitly — root
//  content is edge-to-edge by default. When a screen wants to avoid
//  the dynamic island / home indicator / notch, it wraps its body in
//  `SafeArea { ... }`. Modeled on Flutter's SafeArea widget.
//
//  The `edges` parameter controls which edges are inset:
//
//      SafeArea { HomeView() }                  // all edges
//      SafeArea(edges: .vertical) { ... }       // top + bottom only
//      SafeArea(edges: [.top]) { ... }          // top only
//      SafeArea(edges: .all.subtracting(.bottom)) { ... }
//
//  Implementation: a ContainerView with a single child and a backing
//  UIView that reads its own `safeAreaInsets` in `layoutSubviews` and
//  positions the child with those insets (filtered by `edges`). The
//  child isn't double-inset when composed — a view positioned past
//  the cutouts has `safeAreaInsets == .zero`, so nested SafeArea
//  instances contribute nothing unless they're on a *new* cutout
//  boundary (e.g. inside a modal that introduces its own insets).
//

#if canImport(UIKit)
import UIKit

// MARK: - SafeArea view

public struct SafeArea: ContainerView {
    public let child: any View
    public let edges: Edge.Set
    public let children: [any View]

    public init(
        edges: Edge.Set = .all,
        @ChildBuilder _ content: () -> any View
    ) {
        let built = content()
        self.child = built
        self.edges = edges
        self.children = [built]
    }

    public func makeRenderer() -> ContainerRenderer {
        SafeAreaRenderer(edges: edges)
    }
}

// MARK: - Renderer

final class SafeAreaRenderer: ContainerRenderer {
    private weak var safeAreaView: SafeAreaView?

    var edges: Edge.Set {
        didSet {
            guard let safeAreaView else { return }
            safeAreaView.edges = edges
            safeAreaView.setNeedsLayout()
        }
    }

    init(edges: Edge.Set) {
        self.edges = edges
    }

    func update(from view: any View) {
        guard let safeArea = view as? SafeArea else { return }
        edges = safeArea.edges
    }

    func mount() -> PlatformView {
        let view = SafeAreaView()
        self.safeAreaView = view
        view.edges = edges
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

// MARK: - Backing UIView

final class SafeAreaView: UIView {
    var edges: Edge.Set = .all

    override func layoutSubviews() {
        super.layoutSubviews()
        let insets = resolveInsets()
        subviews.first?.frame = bounds.inset(by: insets)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        // Safe area changes on rotation, keyboard appearance, or when
        // the dynamic island state shifts. Re-layout so the child
        // picks up the new insets.
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
