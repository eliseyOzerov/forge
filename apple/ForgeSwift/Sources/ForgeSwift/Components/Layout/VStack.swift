//
//  VStack.swift
//  ForgeSwift
//
//  First ContainerView. Vertical stack backed by UIStackView. Children
//  are declared at construction and the framework's ContainerNode
//  handles reconciliation (inserts, moves, updates, removes) on
//  rebuilds. Move detection works via `SomeView.id(_:)` — untagged
//  children fall back to position + type matching.
//

#if canImport(UIKit)
import UIKit

public struct VStack: ContainerView {
    public let spacing: CGFloat
    public let children: [any View]

    public init(spacing: CGFloat = 0, children: [any View]) {
        self.spacing = spacing
        self.children = children
    }

    public func makeRenderer() -> ContainerRenderer {
        UIKitVStackRenderer(spacing: spacing)
    }
}

public final class UIKitVStackRenderer: ContainerRenderer {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    public func mount() -> PlatformView {
        let stack = UIStackView()
        stack.axis = .vertical
        apply(to: stack)
        return stack
    }

    public func update(_ platformView: PlatformView) {
        guard let stack = platformView as? UIStackView else { return }
        apply(to: stack)
    }

    public func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        guard let stack = container as? UIStackView else { return }
        stack.insertArrangedSubview(platformView, at: index)
    }

    public func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    public func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        guard let stack = container as? UIStackView else { return nil }
        return stack.arrangedSubviews.firstIndex(of: platformView)
    }

    private func apply(to stack: UIStackView) {
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = spacing
    }
}

#endif
