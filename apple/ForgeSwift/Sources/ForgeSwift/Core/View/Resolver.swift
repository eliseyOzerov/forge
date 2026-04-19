//
//  Resolver.swift
//  ForgeSwift
//
//  Retention root for a mounted tree. All the lifecycle logic
//  (inflation, update, rebuild, unmount) lives on Node. Root exists
//  solely because something needs to hold a strong reference to the
//  root Node for the duration of the presentation — without it,
//  `mount()` would return the root's platform view while the node
//  graph above it gets deallocated, silently killing all state-driven
//  updates.
//

@MainActor public final class Root {
    public init() {}

    /// The mounted root node.
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

// MARK: - PlatformBridge

#if canImport(UIKit)
import UIKit

/// A UIView that hosts a single Forge View. Owns a Root internally —
/// mounts on first call, updates in-place on subsequent calls. The
/// mounted platform view is pinned to the bridge's edges.
@MainActor public final class PlatformBridge: UIView {
    private let root = Root()

    public init(_ view: any View) {
        super.init(frame: .zero)
        updateView(view)
    }

    public convenience init(@ChildBuilder _ content: () -> any View) {
        self.init(content())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func updateView(_ view: any View) {
        if let existing = root.rootNode, existing.canUpdate(to: view) {
            existing.update(from: view)
        } else {
            subviews.forEach { $0.removeFromSuperview() }
            let platform = root.mount(view)
            addSubview(platform)
            platform.pin(to: self)
        }
    }
}
#endif
