//
//  Node.swift
//  SwiftKit
//
//  Node is the long-lived identity anchor. It owns the Model, the
//  Builder/Renderer, the PlatformView, and subscriptions to observables.
//
//  Subscription lifecycle: during a build pass, the Builder calls
//  `node.watch(...)` for each observable it reads. These subscriptions
//  are accumulated on the Node and replace the previous pass's set,
//  so "dependencies" = "observables actually read in the most recent
//  build()". On unmount, all subscriptions are cancelled.
//

@MainActor public class Node {
    public weak var parent: Node?
    public var children: [Node] = []
    public var platformView: PlatformView?

    var subscriptions: [Subscription] = []
    var onDirty: (() -> Void)?

    public init() {}

    /// Read the observable's current value and register this node as a
    /// dependent so a subsequent emission marks the node dirty.
    public func watch<T>(_ observable: Observable<T>) -> T {
        let sub = observable.observe { [weak self] _ in
            self?.markDirty()
        }
        subscriptions.append(sub)
        return observable.value
    }

    public func markDirty() {
        onDirty?()
    }

    /// Called by the Resolver before re-running a composite node's build
    /// so the previous pass's subscriptions don't leak into the new one.
    func beginBuild() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
    }

    func unmount() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
        for child in children { child.unmount() }
        children.removeAll()
        platformView?.removeFromSuperview()
        platformView = nil
    }
}

@MainActor public final class LeafNode: Node {
    public var renderer: Renderer?
}

@MainActor public final class CompositeNode: Node {
    public var model: ViewModel?
    public var builder: Builder?
    public var view: (any View)?
}
