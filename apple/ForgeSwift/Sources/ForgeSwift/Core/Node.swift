//
//  Node.swift
//  ForgeSwift
//
//  Node is the long-lived identity anchor. It owns the Model, the
//  Builder/Renderer, the PlatformView, and subscriptions to observables.
//
//  Lifecycle methods are defined here and overridden by subclasses —
//  LeafNode and CompositeNode each know how to set themselves up,
//  update in place when a parent re-renders them, and tear down.
//  The Resolver is just an entry point + retention root.
//
//  Subscription lifecycle: during a build pass, the Builder calls
//  `context.watch(...)` for each observable it reads. These subscriptions
//  are accumulated on the Node and replace the previous pass's set,
//  so "dependencies" = "observables actually read in the most recent
//  build()". On unmount, all subscriptions are cancelled.
//
//  Identity stability: CompositeNode owns a wrapper PlatformView created
//  at mount time. Its child subtree is placed inside the wrapper. The
//  wrapper identity is stable across rebuilds — only its contents swap.
//  LeafNode preserves its PlatformView across rebuilds too, as long as
//  the new View is the same concrete type; the renderer's `update` path
//  applies new props without tearing down the native object.
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

    var subscriptions: [Subscription] = []
    var onDirty: (() -> Void)?

    public init() {}

    /// Create a new Node for the given View and run its first-time
    /// setup. The returned node is ready to be attached to a parent
    /// container and has its subtree already built.
    public static func inflate(_ view: any View, parent: Node? = nil) -> Node {
        let node = view.makeNode()
        node.parent = parent
        node.setup(from: view)
        return node
    }

    /// First-time initialization. Subclasses override to create their
    /// platform view, renderer, model, builder, and child subtree.
    func setup(from view: any View) {
        self.view = view
    }

    /// Apply a new (same-type) view to this node in place. Subclasses
    /// override to update their platform view, remake their builder
    /// with new props, and reconcile the child subtree without
    /// destroying identity or persistent state.
    func update(from view: any View) {
        self.view = view
    }

    /// Whether this node can be updated in place with the given new
    /// view instead of being torn down and replaced. Default policy
    /// is "same concrete type as the current view."
    public func canUpdate(to newView: any View) -> Bool {
        guard let current = self.view else { return false }
        return type(of: current) == type(of: newView)
    }

    /// Read the observable's current value and register this node as
    /// a dependent so a subsequent emission marks the node dirty.
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

// MARK: - LeafNode

@MainActor public final class LeafNode: Node {
    public var renderer: Renderer?

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let leaf = view as? any LeafView else {
            fatalError("LeafNode.setup called with non-LeafView: \(type(of: view))")
        }
        let renderer = leaf.makeRenderer()
        self.renderer = renderer
        self.platformView = renderer.mount()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard let leaf = view as? any LeafView else {
            fatalError("LeafNode.update called with non-LeafView: \(type(of: view))")
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

// MARK: - CompositeNode

@MainActor public final class CompositeNode: Node {
    public var model: ViewModel?
    public var builder: Builder?
    public var child: Node?

    public override init() {
        super.init()
        self.platformView = PlatformView()
    }

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let composite = view as? any CompositeView else {
            fatalError("CompositeNode.setup called with non-CompositeView: \(type(of: view))")
        }
        makeModelAndBuilder(composite)
        wireOnDirty()
        performBuild()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard let composite = view as? any CompositeView else {
            fatalError("CompositeNode.update called with non-CompositeView: \(type(of: view))")
        }
        // Model is preserved across prop changes; builder is remade
        // from the new view so any new props are captured.
        remakeBuilder(composite)
        performBuild()
    }

    override func unmountChildren() {
        child?.unmount()
        child = nil
    }

    private func makeModelAndBuilder<V: CompositeView>(_ view: V) {
        let model = view.makeModel(node: self)
        let builder = view.makeBuilder(model: model)
        self.model = model
        self.builder = builder
    }

    private func remakeBuilder<V: CompositeView>(_ view: V) {
        guard let existingModel = self.model as? V.ModelType else {
            fatalError("Model type mismatch during CompositeNode.update")
        }
        self.builder = view.makeBuilder(model: existingModel)
    }

    private func wireOnDirty() {
        // Deferred to the next main-actor tick so that if a rebuild is
        // triggered by an input event (button tap), the handler fully
        // unwinds before we touch the views it's attached to.
        self.onDirty = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.performBuild()
            }
        }
    }

    private func performBuild() {
        guard let builder, let wrapper = self.platformView else { return }
        beginBuild()
        let context = BuildContext(node: self)
        let newChildView = builder.build(context)

        if let existingChild = self.child, existingChild.canUpdate(to: newChildView) {
            // Same type at the same position — preserve identity, apply
            // new props through the child's own update path.
            existingChild.update(from: newChildView)
        } else {
            // Type changed or no existing child — blow away and recreate.
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
    /// content via the pinning constraints, so a composite wrapper
    /// inherits its content's natural size without explicit size
    /// constraints.
    private func attach(_ child: PlatformView, inside parent: PlatformView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
    }
}
