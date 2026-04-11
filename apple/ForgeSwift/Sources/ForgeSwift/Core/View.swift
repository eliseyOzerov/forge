//
//  View.swift
//  SwiftKit
//
//  The five-object decomposition:
//    View       — value, cheap, rebuilt on every resolve. Factory for the
//                 rest of the objects. Holds props.
//    Node       — long-lived identity anchor. Owns Model, Builder/Renderer,
//                 platform view, and child nodes. The thing the resolver walks.
//    Renderer   — leaf views only. Translates props to a platform view.
//    Model      — composite views, optional. Long-lived state container.
//                 Holds observables, talks to context/DI.
//    Builder    — composite views. Dumb build function. Depends on a
//                 narrow data protocol, not on the Model directly.
//
//  A View is either Leaf or Composite. These are mutually exclusive and
//  enforced at the protocol level, not at runtime.
//

@MainActor public protocol View {
    func makeNode() -> Node
}

@MainActor public protocol LeafView: View {
    func makeRenderer() -> Renderer
}

public extension LeafView {
    func makeNode() -> Node { LeafNode() }
}

@MainActor public protocol CompositeView: View {
    associatedtype ModelType: ViewModel
    func makeModel(node: Node) -> ModelType
    func makeBuilder(model: ModelType) -> Builder
}

public extension CompositeView {
    func makeNode() -> Node { CompositeNode() }
}

@MainActor public protocol ViewModel: AnyObject {}

public final class EmptyModel: ViewModel {
    public init() {}
}

@MainActor public protocol Builder: AnyObject {
    /// Produces the subtree View for this composite. The context is the
    /// builder's narrow window onto its owning node: it can subscribe to
    /// observables (driving rebuilds) and nothing else. The Node itself
    /// is intentionally hidden so builders can't navigate the tree,
    /// touch lifecycle, or retain node state between passes.
    func build(_ context: BuildContext) -> any View
}

/// A builder's limited view of its owning Node. Instances are created
/// by the Resolver for a single build pass — don't retain them.
@MainActor public struct BuildContext {
    let node: Node

    init(node: Node) {
        self.node = node
    }

    /// Read the observable's current value and register this build pass
    /// as a dependent — a subsequent emission marks the node dirty and
    /// schedules a rebuild.
    public func watch<T>(_ observable: Observable<T>) -> T {
        node.watch(observable)
    }
}

@MainActor public protocol Renderer: AnyObject {
    /// Create a fresh PlatformView from this renderer's props.
    func mount() -> PlatformView

    /// Apply this renderer's props to an already-mounted PlatformView.
    /// Called during rebuild when the leaf node's type hasn't changed —
    /// preserves PlatformView identity and any native state it carries
    /// (scroll position, first responder, in-flight animations, etc.).
    func update(_ platformView: PlatformView)
}
