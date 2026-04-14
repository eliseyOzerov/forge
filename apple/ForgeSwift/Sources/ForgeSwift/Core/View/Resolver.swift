//
//  Resolver.swift
//  ForgeSwift
//
//  Thin entry point + retention root for a mounted tree. All the
//  lifecycle logic (inflation, update, rebuild, unmount) lives on
//  Node. The Resolver exists solely because something needs to hold
//  a strong reference to the root Node for the duration of the
//  presentation — without it, `mount()` would return the root's
//  platform view while the node graph above it gets deallocated,
//  silently killing all state-driven updates.
//

@MainActor public final class Resolver {
    public init() {}

    /// The mounted root. Exposed (read-only) for views that compose
    /// multiple Resolvers and need to reconcile across updates.
    public private(set) var rootNode: Node?

    public func mount(_ view: any View) -> PlatformView {
        let node = Node.inflate(view)
        self.rootNode = node
        guard let platform = node.platformView else {
            fatalError("Root node produced no platform view")
        }
        return platform
    }
}
