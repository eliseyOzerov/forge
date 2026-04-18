//
//  Ref.swift
//  ForgeSwift
//
//  External reference to a mounted view's node and model.
//  Keyed by view type — `Ref<Router>` will only be populated by a
//  Router node, not by any other view in the subtree.
//
//  Usage:
//
//      let router = Ref<Router>()
//
//      Router { HomeView() }.ref(router)
//
//      router.model?.push(Screen { DetailView() })
//      router.context  // ViewContext for the Router's node
//

// MARK: - Ref

@MainActor
public class Ref<V: View> {
    /// The node backing the referenced view. Set automatically by the
    /// node system on mount; nils out when the node is deallocated
    /// (weak reference).
    public internal(set) weak var node: Node?

    public init() {}

    /// The node's ViewContext, if mounted.
    public var context: ViewContext? { node }
}

// MARK: - Model access for ModelView

public extension Ref where V: ModelView {
    /// Typed access to the view's model, if mounted.
    var model: V.Model? {
        (node as? ModelNode)?.model as? V.Model
    }
}

// MARK: - View modifier

public extension View {
    /// Attach a Ref so the nearest descendant node matching the Ref's
    /// view type will populate it on mount. Internally wraps the view
    /// in a Provided so the ref travels down the tree.
    func ref<R: View>(_ ref: Ref<R>) -> any View {
        Provided(ref) { self }
    }
}
