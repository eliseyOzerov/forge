//
//  Node.swift
//  ForgeSwift
//
//  Node is the long-lived identity anchor. It owns the Model, the
//  Builder/Renderer, the PlatformView, and subscriptions.
//
//  Lifecycle methods live here and are overridden by subclasses —
//  LeafNode, BuiltNode, ModelNode, and ContainerNode each know how
//  to set themselves up, update in place, reconcile children, and
//  tear down. The Resolver is just an entry point + retention root.
//
//  BuiltNode vs ModelNode split: BuiltNode backs stateless composites
//  (BuiltView) and has no Model/Builder slot. ModelNode backs
//  stateful composites (ModelView) and owns the Model/Builder plus
//  the lifecycle dispatch. Both wire `onDirty` so upstream observable
//  emissions (Provided, context.watch) still drive rebuilds; the
//  only difference is ModelNode additionally exposes user-triggered
//  rebuild paths through its Model.
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

/// Transparent wrapper view used by BuiltNode and ModelNode.
/// Delegates sizing to its single child and pins that child to fill.
#if canImport(UIKit)
class ProxyView: UIView {
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        subviews.first?.intrinsicContentSize ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func setNeedsLayout() {
        super.setNeedsLayout()
        superview?.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds
    }

    /// Unwrap through proxies to find the innermost BoxView's sizing.
    var innerSizing: Frame? {
        if let box = subviews.first as? BoxView { return box.sizing }
        if let proxy = subviews.first as? ProxyView { return proxy.innerSizing }
        return nil
    }
}
#elseif canImport(AppKit)
class ProxyView: NSView {
    override var intrinsicContentSize: NSSize {
        subviews.first?.intrinsicContentSize ?? NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
#endif

@MainActor public class Node {
    public weak var parent: Node?
    public var platformView: PlatformView?
    public var view: (any View)?
    public var id: AnyHashable?

    var subscriptions: [Subscription] = []
    var onDirty: (() -> Void)?

    /// Values injected into the subtree by a Provided<T> view. Keyed
    /// by the provided type. Each slot wraps an Observable so consumer
    /// nodes can subscribe and rebuild when the provider replaces the
    /// value. Walked by findSlot via the parent chain.
    var providedSlots: [ObjectIdentifier: AnyProvidedSlot] = [:]

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
        populateRef(view)
    }

    /// Auto-populate a Ref<V> if one was provided from an ancestor.
    /// Opens the existential to get the concrete view type, then looks
    /// for a Provided Ref keyed by that type.
    private func populateRef<V: View>(_ view: V) {
        if let ref = findSlot(Ref<V>.self)?.observable.value {
            ref.node = self
        }
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

    /// Type-erased subscribe-and-mark-dirty. Used by Provided/consumer
    /// machinery to subscribe to an Observable whose element type the
    /// caller doesn't know statically.
    public func watchAny(_ listenable: Listenable) {
        let sub = listenable.listen { [weak self] in
            self?.markDirty()
        }
        subscriptions.append(sub)
    }

    /// Install or update a Provided<T> slot on this node. Called by
    /// Provided.build during the provider's own build pass. If a slot
    /// for T already exists, its observable is updated (firing
    /// observers — i.e. consumer nodes rebuild). Otherwise a fresh
    /// slot is created. v1: always fires on update; equality-skip is
    /// a future optimization.
    public func installSlot<T>(_ value: T) {
        let key = ObjectIdentifier(T.self)
        if let existing = providedSlots[key] as? ProvidedSlot<T> {
            existing.observable.value = value
        } else {
            providedSlots[key] = ProvidedSlot(value)
        }
    }

    /// Walk the parent chain looking for a Provided<T> slot. Returns
    /// the first match, or nil if no ancestor provides T. v1 walks
    /// every call — caching is a future optimization.
    public func findSlot<T>(_ type: T.Type) -> ProvidedSlot<T>? {
        let key = ObjectIdentifier(type)
        if let slot = providedSlots[key] as? ProvidedSlot<T> { return slot }
        return parent?.findSlot(type)
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

// MARK: - ViewContext conformance

/// Node is the concrete implementation of `ViewContext`. The
/// framework passes a Node (typed as `ViewContext`) into every
/// `build(context:)` and `model(context:)` so consumer code only
/// sees the documented surface, not Node's lifecycle internals.
extension Node: ViewContext {
    /// Flutter-style setState. Runs the mutation closure synchronously,
    /// then marks the owning node dirty, scheduling a rebuild on the
    /// next main-actor tick.
    public func rebuild(_ mutation: () -> Void) {
        mutation()
        markDirty()
    }

    /// One-shot read of the nearest ancestor's `Provided<T>` value.
    /// No subscriptions. Fatal if no provider is found.
    public func read<T>(_ type: T.Type) -> T {
        guard let slot = findSlot(type) else {
            fatalError("No Provided<\(T.self)> found in ancestors. " +
                       "Wrap your subtree in Provided(\(T.self)(...)) { ... }, " +
                       "or use maybeRead(\(T.self).self) for optional access.")
        }
        return slot.observable.value
    }

    /// Optional one-shot read. No subscriptions.
    public func tryRead<T>(_ type: T.Type) -> T? {
        findSlot(type)?.observable.value
    }

    /// Subscribing read. Registers this build pass on slot replacement
    /// AND — if the value is `Listenable` — on the value's own
    /// in-place mutations.
    public func watch<T>(_ type: T.Type) -> T {
        guard let slot = findSlot(type) else {
            fatalError("No Provided<\(T.self)> found in ancestors. " +
                       "Wrap your subtree in Provided(\(T.self)(...)) { ... }, " +
                       "or use maybeWatch(\(T.self).self) for optional access.")
        }
        let value = watch(slot.observable)
        if let observable = value as? Listenable {
            watchAny(observable)
        }
        return value
    }

    /// Optional subscribing read. Nil if no ancestor provides T.
    public func tryWatch<T>(_ type: T.Type) -> T? {
        guard let slot = findSlot(type) else { return nil }
        let value = watch(slot.observable)
        if let observable = value as? Listenable {
            watchAny(observable)
        }
        return value
    }
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
        renderer?.update(from: self.view!)
    }
}

// MARK: - BuiltNode

/// Backs stateless composites (BuiltView). No Model slot, no user-
/// triggered rebuild path. `onDirty` is wired so upstream observable
/// emissions (Provided changes, `context.watch`) still re-run build.
public final class BuiltNode: Node {
    public var child: Node?

    public override init() {
        super.init()
        self.platformView = ProxyView()
    }

    override func setup(from view: any View) {
        super.setup(from: view)
        guard self.view is any BuiltView else {
            fatalError("BuiltNode.setup called with non-BuiltView: \(type(of: self.view!))")
        }
        wireOnDirty()
        performBuild()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard self.view is any BuiltView else {
            fatalError("BuiltNode.update called with non-BuiltView: \(type(of: self.view!))")
        }
        performBuild()
    }

    override func unmountChildren() {
        child?.unmount()
        child = nil
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

        guard let built = self.view as? any BuiltView else {
            fatalError("BuiltNode has no build path")
        }
        let newChildView = built.build(context: self)

        reconcileChild(newChildView, into: wrapper)
    }

    private func reconcileChild(_ newChildView: any View, into wrapper: PlatformView) {
        if let existingChild = self.child, existingChild.canUpdate(to: newChildView) {
            existingChild.update(from: newChildView)
        } else {
            self.child?.unmount()
            self.child = nil
            let newChild = Node.inflate(newChildView, parent: self)
            self.child = newChild
            if let childPlatform = newChild.platformView {
                wrapper.addSubview(childPlatform)
            }
        }
    }
}

// MARK: - OffstageNode

/// Backs `Offstage`. Mounts the child once and keeps it alive in the
/// tree, but when offstage: hides the platform view, reports zero
/// size, and skips child updates. When the view transitions from
/// offstage to onstage (or vice versa), the child is shown/hidden
/// without remounting.
public final class OffstageNode: Node {
    public var child: Node?
    private var isOffstage: Bool = true

    public override init() {
        super.init()
        self.platformView = OffstageView()
    }

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let offstage = self.view as? Offstage else {
            fatalError("OffstageNode.setup called with non-Offstage")
        }
        isOffstage = offstage.offstage

        let childNode = Node.inflate(offstage.child, parent: self)
        self.child = childNode
        if let childPlatform = childNode.platformView,
           let wrapper = self.platformView {
            wrapper.addSubview(childPlatform)
        }

        applyOffstage()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard let offstage = self.view as? Offstage else {
            fatalError("OffstageNode.update called with non-Offstage")
        }
        let wasOffstage = isOffstage
        isOffstage = offstage.offstage

        // Only update the child when onstage.
        if !isOffstage {
            if let existing = child, existing.canUpdate(to: offstage.child) {
                existing.update(from: offstage.child)
            } else {
                child?.unmount()
                let newChild = Node.inflate(offstage.child, parent: self)
                self.child = newChild
                if let childPlatform = newChild.platformView,
                   let wrapper = self.platformView {
                    wrapper.addSubview(childPlatform)
                }
            }
        }

        if wasOffstage != isOffstage {
            applyOffstage()
        }
    }

    override func unmountChildren() {
        child?.unmount()
        child = nil
    }

    private func applyOffstage() {
        (platformView as? OffstageView)?.isOffstage = isOffstage
    }
}

#if canImport(UIKit)
/// Platform view that reports zero size when offstage and hides
/// its content. When onstage, passes through to the child's size.
final class OffstageView: UIView {
    var isOffstage: Bool = true {
        didSet {
            guard isOffstage != oldValue else { return }
            isHidden = isOffstage
            superview?.setNeedsLayout()
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if isOffstage { return .zero }
        return subviews.first?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        if isOffstage {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        return subviews.first?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds
    }
}
#endif

// MARK: - ModelNode

/// Backs stateful composites (ModelView). Owns the Model (created
/// once at mount via `model(context:)`) and produces a fresh Builder
/// each render via `builder(model:)`. Dispatches lifecycle hooks
/// (`didInit`, `didUpdate`, `didRebuild`, `didDispose`) through
/// `ModelLifecycle` — closure handles captured at mount that open
/// the Model's associated View type so the node can call the typed
/// `didUpdate(oldView:newView:)` without carrying the generic around.
public final class ModelNode: Node {
    public var model: AnyObject?
    public var child: Node?
    private var lifecycle: ModelLifecycle?

    public override init() {
        super.init()
        self.platformView = ProxyView()
    }

    override func setup(from view: any View) {
        super.setup(from: view)
        guard let modelView = self.view as? any ModelView else {
            fatalError("ModelNode.setup called with non-ModelView: \(type(of: self.view!))")
        }
        makeModel(for: modelView)
        wireOnDirty()
        performBuild()
    }

    override func update(from view: any View) {
        super.update(from: view)
        guard self.view is any ModelView, let newView = self.view else {
            fatalError("ModelNode.update called with non-ModelView: \(type(of: self.view!))")
        }
        lifecycle?.didUpdate(newView)
        performBuild()
    }

    override func unmountChildren() {
        child?.unmount()
        child = nil
    }

    override func unmount() {
        lifecycle?.didDispose()
        super.unmount()
    }

    /// Create the Model and capture typed lifecycle handles. Generic
    /// bounce — opens the existential `any ModelView` to recover V,
    /// which in turn gives us V.Model for subsequent typed dispatch.
    private func makeModel<V: ModelView>(for view: V) {
        let model = view.model(context: self)
        model.didInit(view: view)
        self.model = model
        self.lifecycle = ModelLifecycle(
            didUpdate: { [weak model] newAny in
                guard let model, let newView = newAny as? V else { return }
                model.didUpdate(newView: newView)
            },
            didRebuild: { [weak model] in model?.didRebuild() },
            didDispose: { [weak model] in model?.didDispose() }
        )
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
        guard let modelView = self.view as? any ModelView else {
            fatalError("ModelNode has no ModelView in self.view")
        }
        beginBuild()
        let newChildView = buildChildView(for: modelView, context: self)
        reconcileChild(newChildView, into: wrapper)
        lifecycle?.didRebuild()
    }

    /// Produce the child view by constructing a fresh Builder from
    /// the current Model and calling its `build(context:)`. Generic
    /// bounce mirrors `makeModel` — opening V gives us V.Model so we
    /// can downcast `self.model` and typecheck `builder(model:)`.
    private func buildChildView<V: ModelView>(for view: V, context: ViewContext) -> any View {
        guard let model = self.model as? V.Model else {
            fatalError("ModelNode has no Model of the expected type")
        }
        let builder = view.builder(model: model)
        return builder.build(context: context)
    }

    private func reconcileChild(_ newChildView: any View, into wrapper: PlatformView) {
        if let existingChild = self.child, existingChild.canUpdate(to: newChildView) {
            existingChild.update(from: newChildView)
        } else {
            self.child?.unmount()
            self.child = nil
            let newChild = Node.inflate(newChildView, parent: self)
            self.child = newChild
            if let childPlatform = newChild.platformView {
                wrapper.addSubview(childPlatform)
            }
        }
    }
}

/// Closure-captured lifecycle dispatch for a ModelNode. The closures
/// are constructed inside the generic bounce in `makeModel(for:)`,
/// which means they can close over the typed `V` (and the typed
/// Model conforming to `ViewModel<V>`) without the ModelNode itself
/// carrying either as a stored generic parameter.
private struct ModelLifecycle {
    let didUpdate: (Any) -> Void
    let didRebuild: () -> Void
    let didDispose: () -> Void
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
        guard let container = self.view as? any ContainerView, let renderer else {
            fatalError("ContainerNode.update called with non-ContainerView: \(type(of: self.view!))")
        }

        renderer.update(from: self.view!)
        reconcileChildren(container.children, renderer: renderer)
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
