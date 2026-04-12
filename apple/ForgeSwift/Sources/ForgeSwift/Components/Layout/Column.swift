#if canImport(UIKit)
import UIKit

/// Vertical stack. Distributes children sequentially along the vertical axis.
public struct Column: ContainerView {
    public let spacing: Double
    public let children: [any View]

    public init(spacing: Double = 0, children: [any View]) {
        self.spacing = spacing
        self.children = children
    }

    public init(spacing: Double = 0, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing
        self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        StackRenderer(axis: .vertical, spacing: spacing)
    }
}

/// Horizontal stack. Distributes children sequentially along the horizontal axis.
public struct Row: ContainerView {
    public let spacing: Double
    public let children: [any View]

    public init(spacing: Double = 0, children: [any View]) {
        self.spacing = spacing
        self.children = children
    }

    public init(spacing: Double = 0, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing
        self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        StackRenderer(axis: .horizontal, spacing: spacing)
    }
}

// MARK: - Shared Renderer

final class StackRenderer: ContainerRenderer {
    let axis: NSLayoutConstraint.Axis
    let spacing: Double

    init(axis: NSLayoutConstraint.Axis, spacing: Double) {
        self.axis = axis
        self.spacing = spacing
    }

    func mount() -> PlatformView {
        let stack = UIStackView()
        apply(to: stack)
        return stack
    }

    func update(_ platformView: PlatformView) {
        guard let stack = platformView as? UIStackView else { return }
        apply(to: stack)
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        guard let stack = container as? UIStackView else { return }
        stack.insertArrangedSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        guard let stack = container as? UIStackView else { return nil }
        return stack.arrangedSubviews.firstIndex(of: platformView)
    }

    private func apply(to stack: UIStackView) {
        stack.axis = axis
        stack.alignment = .fill
        stack.spacing = spacing
    }
}

#endif
