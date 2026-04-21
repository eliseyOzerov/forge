//
//  Ref.swift
//  ForgeSwift
//
//  General-purpose reference. When typed by a View, the node system
//  auto-populates it on mount. Conditional extensions add .context
//  and .model for View and ModelView types respectively.
//
//  Usage:
//
//      @Ref<Router> var router
//
//      Router { HomeView() }.ref(router)
//
//      router.model?.push(Screen { DetailView() })
//      router.context  // ViewContext for the Router's node
//

// MARK: - Ref

/// Property wrapper for obtaining a reference to a mounted view's Node.
@propertyWrapper
@MainActor
public class Ref<V: View> {
    /// Node backing, populated by the node system on mount.
    public internal(set) weak var node: Node?

    public var wrappedValue: Ref<V> { self }
    public var projectedValue: Ref<V> { self }

    public init() {}

    /// The node's ViewContext, if mounted.
    public var context: ViewContext? { node }
}

// MARK: - Model access

public extension Ref where V: ModelView {
    /// Typed access to the view's model, if mounted.
    var model: V.Model? {
        (node as? ModelNode)?.model as? V.Model
    }
}

// MARK: - View modifier

public extension View {
    /// Provide a Ref into the subtree. The node system auto-populates
    /// View-typed refs when a matching node mounts.
    func ref<V: View>(_ ref: Ref<V>) -> any View {
        Provided(ref) { self }
    }
}
