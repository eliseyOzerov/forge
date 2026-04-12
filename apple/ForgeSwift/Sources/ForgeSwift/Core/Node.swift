//
//  Node.swift
//  ForgeSwift
//
//  Node is the long-lived identity anchor. It owns the Model, the
//  Builder/Renderer, the PlatformView, and subscriptions.
//
//  Lifecycle methods live here and are overridden by subclasses —
//  LeafNode, ComposedNode, and ContainerNode each know how to set
//  themselves up, update in place, reconcile children, and tear down.
//  The Resolver is just an entry point + retention root.
//
//  Identity: nodes carry an optional `id: AnyHashable?` extracted
//  from an IdentifiedView wrapper at inflation / update time. The
//  reconciler uses these ids for move detection and cross-rebuild
//  state preservation. All non-container update paths go through
//  Node.setup(from:) and Node.update(from:), which call unwrapIdentity
//  so subclass overrides can read self.view as the unwrapped inner
//  view without worrying about the wrapper.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor public class Node {
    public weak var parent: Node?
    public var platformView: PlatformView?
    public var view: (any View)?
    public var id: AnyHashable?

    var subscriptions: [Subscription] = []
    var onDirty: (() -> Void)?

    public init() {}

    /// Create a new Node for the given View and run its first-time
    /// setup. Unwraps any IdentifiedView wrapper so the resulting
    /// node's self.view is the inner view and self.id is the
    /// extracted identity.
    public static func inflate(_ view: any View, parent: Node? = nil) -> Node {
        let (id, inner) = unwrapIdentity(view)
        let node = inner.makeNode()
        node.parent = parent
        node.id = id
        node.setup(from: inner)
        return node
    }

    /// First-time initialization. Base class stores the (unwrapped)
    /// view; subclasses override to create their platform view,
    /// renderer, model, builder, and child subtree.
    func setup(from view: any View) {
        self.view = view
    }

    /// Apply a new view to this node in place. Base class unwraps
    /// any IdentifiedView, updates self.view and self.id, then hands
    /// off to subclass overrides.
    func update(from view: any View) {
        let (id, inner) = unwrapIdentity(view)
        self.id = id
        self.view = inner
    }

    /// Whether this node can be updated in place with the given new
    /// view. Compares the concrete type of self.view with the
    /// unwrapped inner of newView — unwrapping is necessary so a
    /// Text and Text.id(1) are recognized as the same type.
    public func canUpdate(to newView: any View) -> Bool {
        let (_, inner) = unwrapIdentity(newView)
        guard let current = self.view else { return false }
        return type(of: current) == type(of: inner)
    }

    /// Read an observable's current value and register this node as
    /// a dependent so a subsequent emission marks it dirty. Used by
    /// BuildContext.watch; the local-state rebuild pattern doesn't
    /// use this — it calls markDirty() directly from ViewModel.rebuild.
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

    /// Clears the previous build pass's subscriptions. Called by the
    /// node itself before re-running its builder.
    func beginBuild() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
    }

    func unmount() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
        unmountChildren()
        platformView?.removeFromSuperview()
        platformView = nil
    }

    /// Override in subclasses that have children.
    func unmountChildren() {}
}

/// Peel an IdentifiedView wrapper (possibly nested) to extract the
/// outermost id and the fully-unwrapped inner view.
@MainActor
func unwrapIdentity(_ view: any View) -> (id: AnyHashable?, inner: any View) {
    var current: any View = view
    var id: AnyHashable? = nil
    while let identified = current as? any Identified {
        if id == nil { id = identified.id }
        current = identified.child
    }
    return (id, current)
}

// MARK: - LeafNode

public final class LeafNode: Node {
    public var renderer: Renderer?

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let leaf = self.view as? any LeafView else {
            fatalError("LeafNode.setup called with non-LeafView: \(type(of: self.view!))")
        }
        let renderer = leaf.makeRenderer()
        self.renderer = renderer
        self.platformView = renderer.mount()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard let leaf = self.view as? any LeafView else {
            fatalError("LeafNode.update called with non-LeafView: \(type(of: self.view!))")
        }
        // Fresh renderer holds the new props; apply them to the
        // existing PlatformView so its identity and native state are
        // preserved. Old renderer is discarded.
        let newRenderer = leaf.makeRenderer()
        if let platformView = self.platformView {
            newRenderer.update(platformView)
        }
        self.renderer = newRenderer
    }
}

// MARK: - ComposedNode

public final class ComposedNode: Node {
    public var model: ViewModelBase?
    public var builder: Builder?
    public var child: Node?

    public override init() {
        super.init()
        self.platformView = PlatformView()
    }

    override func setup(from view: any View) {
        super.setup(from: view)
        guard self.view is any ComposedView else {
            fatalError("ComposedNode.setup called with non-ComposedView: \(type(of: self.view!))")
        }
        if let modelView = self.view as? any ModelView {
            makeModelAndBuilder(modelView)
        }
        wireOnDirty()
        performBuild()
    }

    override func update(from view: any View) {
        let oldView = self.view
        super.update(from: view)
        guard self.view is any ComposedView else {
            fatalError("ComposedNode.update called with non-ComposedView: \(type(of: self.view!))")
        }
        if self.view is any ModelView, let oldView {
            model?.handleDidUpdate(self.view!, oldView: oldView)
        }
        performBuild()
    }

    override func unmountChildren() {
        child?.unmount()
        child = nil
    }

    override func unmount() {
        model?.willUnmount()
        super.unmount()
    }

    private func makeModelAndBuilder<V: ModelView>(_ view: V) {
        let context = BuildContext(node: self)
        let model = view.makeModel(context: context)
        model.node = self
        model.handleDidInit(view)
        let builder = view.makeBuilder()
        builder.model = model
        self.model = model
        self.builder = builder
    }

    private func wireOnDirty() {
        self.onDirty = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.performBuild()
            }
        }
    }

    private func performBuild() {
        guard let wrapper = self.platformView else { return }
        beginBuild()
        let context = BuildContext(node: self)

        let newChildView: any View
        if let builder = self.builder {
            newChildView = builder.build(context: context)
        } else if let composed = self.view as? any ComposedView {
            newChildView = composed.build(context: context)
        } else {
            fatalError("ComposedNode has no build path")
        }

        if let existingChild = self.child, existingChild.canUpdate(to: newChildView) {
            existingChild.update(from: newChildView)
        } else {
            self.child?.unmount()
            self.child = nil
            let newChild = Node.inflate(newChildView, parent: self)
            self.child = newChild
            if let childPlatform = newChild.platformView {
                attach(childPlatform, inside: wrapper)
            }
        }
    }

    /// Pin `child` to fill `parent`. Parent sizes to child's intrinsic
    /// content via the pinning constraints.
    private func attach(_ child: PlatformView, inside parent: PlatformView) {
        parent.addSubview(child)
        child.pin(to: parent)
    }
}

// MARK: - ContainerNode

public final class ContainerNode: Node {
    public var renderer: ContainerRenderer?
    public var childNodes: [Node] = []

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let container = self.view as? any ContainerView else {
            fatalError("ContainerNode.setup called with non-ContainerView: \(type(of: self.view!))")
        }
        let renderer = container.makeRenderer()
        self.renderer = renderer
        self.platformView = renderer.mount()

        // Initial child inflate — straight append, no reconciliation
        // needed since the stack is empty.
        guard let containerPlatform = self.platformView else { return }
        for (i, childView) in container.children.enumerated() {
            let childNode = Node.inflate(childView, parent: self)
            childNodes.append(childNode)
            if let childPlatform = childNode.platformView {
                renderer.insert(childPlatform, at: i, into: containerPlatform)
            }
        }
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard let container = self.view as? any ContainerView else {
            fatalError("ContainerNode.update called with non-ContainerView: \(type(of: self.view!))")
        }

        // Remake renderer with new props (spacing, alignment, etc.),
        // apply to existing stack view.
        let newRenderer = container.makeRenderer()
        if let platformView = self.platformView {
            newRenderer.update(platformView)
        }
        self.renderer = newRenderer

        reconcileChildren(container.children, renderer: newRenderer)
    }

    override func unmountChildren() {
        for node in childNodes { node.unmount() }
        childNodes.removeAll()
    }

    /// Tier-2 reconciliation: match by id if present, fall back to
    /// position + type. Handles inserts, moves, updates, and removes.
    ///
    /// Phases:
    ///   1. Match old nodes to new views, inflate anything unmatched,
    ///      and apply updates in place. Builds `targetNodes`, the
    ///      full new child list.
    ///   2. Remove orphaned old nodes (not matched to any new view).
    ///   3. Position pass: walk `targetNodes` left to right, ensuring
    ///      each node's platform view is at its target stack index —
    ///      moving or inserting as needed.
    private func reconcileChildren(_ newChildren: [any View], renderer: ContainerRenderer) {
        guard let container = self.platformView else { return }

        let oldChildren = childNodes

        // Build lookup: id → old index (for nodes that have an id)
        var oldById: [AnyHashable: Int] = [:]
        for (i, node) in oldChildren.enumerated() {
            if let id = node.id {
                oldById[id] = i
            }
        }

        var targetNodes: [Node] = []
        var consumed = Set<Int>()

        // Phase 1: match + update in place + inflate
        for (newIdx, newView) in newChildren.enumerated() {
            let newId = Self.extractId(newView)
            var matched: Node? = nil

            if let newId {
                // Tagged: strict id match, no position fallback.
                if let oldIdx = oldById[newId],
                   !consumed.contains(oldIdx),
                   oldChildren[oldIdx].canUpdate(to: newView) {
                    consumed.insert(oldIdx)
                    matched = oldChildren[oldIdx]
                }
            } else {
                // Untagged: position + type fallback.
                if newIdx < oldChildren.count,
                   !consumed.contains(newIdx),
                   oldChildren[newIdx].canUpdate(to: newView) {
                    consumed.insert(newIdx)
                    matched = oldChildren[newIdx]
                }
            }

            if let matched {
                matched.update(from: newView)
                targetNodes.append(matched)
            } else {
                let fresh = Node.inflate(newView, parent: self)
                targetNodes.append(fresh)
            }
        }

        // Phase 2: remove orphans
        for (oldIdx, oldNode) in oldChildren.enumerated() where !consumed.contains(oldIdx) {
            if let oldPlatform = oldNode.platformView {
                renderer.remove(oldPlatform, from: container)
            }
            oldNode.unmount()
        }

        // Phase 3: position pass
        // For each target index, ensure the correct platform view is
        // at that slot. Move if elsewhere in the container, insert if
        // not yet present. firstIndex is re-queried each iteration
        // because prior moves/inserts shift container indices.
        for (targetIdx, node) in targetNodes.enumerated() {
            guard let platformView = node.platformView else { continue }
            let currentIdx = renderer.index(of: platformView, in: container)
            if currentIdx == targetIdx { continue }
            if currentIdx != nil {
                renderer.move(platformView, to: targetIdx, in: container)
            } else {
                renderer.insert(platformView, at: targetIdx, into: container)
            }
        }

        self.childNodes = targetNodes
    }

    /// Extract the outermost id from a view, peeling IdentifiedView
    /// wrappers as needed. Returns nil if no wrapper is present.
    private static func extractId(_ view: any View) -> AnyHashable? {
        var current: any View = view
        while let identified = current as? any Identified {
            return identified.id
        }
        _ = current
        return nil
    }
}
