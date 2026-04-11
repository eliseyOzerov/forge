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
    /// Set by the Resolver after construction. Builders use this to
    /// read-and-subscribe observables via `node.watch(...)`.
    var node: Node? { get set }

    func build() -> any View
}

@MainActor public protocol Renderer: AnyObject {
    func mount() -> PlatformView
}
