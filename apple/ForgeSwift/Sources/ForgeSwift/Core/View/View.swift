//
//  View.swift
//  ForgeSwift
//
//  The five-object decomposition:
//    View       — value, cheap, rebuilt on every resolve. Factory for
//                 the rest of the objects. Holds props.
//    Node       — long-lived identity anchor. Owns Model, Builder/
//                 Renderer, platform view, and child nodes. The thing
//                 the resolver walks.
//    Renderer   — leaf views only. Translates props to a platform view,
//                 both at mount and on in-place updates.
//    ViewModel  — composite views with state. Long-lived state
//                 container. Has a rebuild(_:) method that mutates
//                 state and schedules a rebuild of the owning node
//                 (Flutter's setState pattern).
//    Builder    — composite views. Dumb build function over a
//                 ViewModel. ViewBuilder<T> is the convenience base.
//
//  A View is either Leaf or Composed. A ComposedView without state
//  implements build(context:) directly. A ComposedView with state
//  conforms to ModelView — the framework routes its build through
//  a Builder created via makeBuilder(model:).
//

@MainActor public protocol View {
    func makeNode() -> Node
}

// MARK: - Leaf

@MainActor public protocol LeafView: View {
    func makeRenderer() -> Renderer
}

public extension LeafView {
    func makeNode() -> Node { LeafNode() }
}

// MARK: - Composed

/// A View composed of other views via a build function. Stateless
/// composites implement `build(context:)` directly. Stateful
/// composites conform to `ModelView` instead.
@MainActor public protocol ComposedView: View {
    func build(context: BuildContext) -> any View
}

public extension ComposedView {
    func makeNode() -> Node { ComposedNode() }
}

/// A ComposedView with a persistent ViewModel and Builder. The
/// framework routes build requests through the Builder returned by
/// `makeBuilder()` — implementers should not override
/// `build(context:)` themselves (its default is a fatalError stub).
///
/// The framework creates the model via `makeModel`, calls its
/// lifecycle hooks (`didInit` / `didUpdate`), creates the builder
/// via `makeBuilder()`, and wires the model onto the builder. The
/// builder reads all data from the model — no extra constructor
/// arguments needed.
@MainActor public protocol ModelView: ComposedView {
    associatedtype ModelType: ViewModelBase
    associatedtype BuilderType: ViewBuilder<ModelType>
    func makeModel(context: BuildContext) -> ModelType
    func makeBuilder() -> BuilderType
}

public extension ModelView {
    /// Stub. The framework calls the Builder's build directly; this
    /// default exists only to satisfy the ComposedView requirement
    /// and should never be invoked at runtime. ModelView implementers
    /// should not override it.
    func build(context: BuildContext) -> any View {
        fatalError(
            "ModelView.build(context:) should never be called directly. " +
            "The framework routes builds through the Builder returned " +
            "by makeBuilder(model:)."
        )
    }
}

// MARK: - ViewModel

/// Non-generic base class for the framework's internal bookkeeping.
/// Users should subclass `ViewModel<V>` instead.
@MainActor open class ViewModelBase {
    public weak var node: Node?

    public init() {}

    /// Flutter-style setState. Runs the mutation closure synchronously,
    /// then marks the owning node dirty — which schedules a rebuild
    /// on the next main-actor tick.
    public func rebuild(_ mutation: () -> Void) {
        mutation()
        node?.markDirty()
    }

    // Framework-internal lifecycle dispatch. Overridden by ViewModel<V>.
    func handleDidInit(_ view: any View) {}
    func handleDidUpdate(_ view: any View, oldView: any View) {}
    open func willUnmount() {}
}

/// Typed ViewModel base class. Subclass this with your ModelView's
/// type as the generic parameter to get typed access to the view's
/// props via `self.view`.
///
///     final class CounterModel: ViewModel<Counter> {
///         var count = 0
///         override func didInit() { /* self.view.initialCount */ }
///     }
@MainActor open class ViewModel<V: ModelView>: ViewModelBase {
    public private(set) var view: V!

    override func handleDidInit(_ view: any View) {
        self.view = (view as! V)
        didInit()
    }

    override func handleDidUpdate(_ view: any View, oldView: any View) {
        let oldView = oldView as! V
        self.view = (view as! V)
        didUpdate(from: oldView)
    }

    /// Called once after the model is created and wired to the node.
    /// The view's props are available via `self.view`.
    open func didInit() {}

    /// Called when the parent rebuilds and passes new props to this
    /// view. `self.view` is already the new view; `oldView` is the
    /// previous instance for comparison.
    open func didUpdate(from oldView: V) {}
}

// MARK: - Builder

@MainActor public protocol Builder: AnyObject {
    /// Produces the subtree View for this composite. The context is
    /// a narrow window onto the owning node.
    func build(context: BuildContext) -> any View
}

/// Convenience base class for builders that operate on a specific
/// ViewModel subclass. The framework assigns `model` after
/// construction — subclasses just override `build(context:)`.
@MainActor open class ViewBuilder<T: ViewModelBase>: Builder {
    public var model: T!

    public init() {}

    open func build(context: BuildContext) -> any View {
        fatalError("ViewBuilder subclass must override build(context:)")
    }

    /// Create a two-way Binding from a keypath on this builder's
    /// model. Writes through the binding call rebuild { ... } on the
    /// model, which marks the owning composite node dirty and
    /// schedules a rebuild of its subtree on the next main-actor
    /// tick. Lives on ViewBuilder (not ViewModel) because the
    /// generic parameter T gives Swift the concrete model type it
    /// needs for keypath inference.
    public func bind<Value>(_ keyPath: ReferenceWritableKeyPath<T, Value>) -> Binding<Value> {
        let model = self.model!
        return Binding(
            get: { model[keyPath: keyPath] },
            set: { newValue in
                model.rebuild { model[keyPath: keyPath] = newValue }
            }
        )
    }
}

// MARK: - BuildContext

/// A builder's limited view of its owning Node. Instances are
/// created by the framework per build pass — don't retain them.
/// Also passed to ModelView.makeModel so models can do one-time
/// context-aware setup (DI lookups, etc., once we grow those APIs).
@MainActor public struct BuildContext {
    let node: Node

    init(node: Node) {
        self.node = node
    }

    /// Read an Observable's current value and subscribe this build
    /// pass to its changes. Currently vestigial — the preferred
    /// pattern for local state is a ViewModel + rebuild { ... }, not
    /// observables. Kept for cases where a leaf needs to subscribe
    /// to an externally-owned observable.
    public func watch<T>(_ observable: Observable<T>) -> T {
        node.watch(observable)
    }
}

// MARK: - Container

/// A View with a fixed list of child views and a native container
/// platform view (UIStackView, etc.). Distinct from ComposedView —
/// children are declared data, not produced by a build function.
/// Reconciliation is handled by ContainerNode, which matches children
/// by id (if provided via `.id(_:)`) or by position + type.
@MainActor public protocol ContainerView: View {
    var children: [any View] { get }
    func makeRenderer() -> ContainerRenderer
}

public extension ContainerView {
    func makeNode() -> Node { ContainerNode() }
}

/// Renderer for ContainerView. Adds insert/remove/move/index methods
/// so the framework can manipulate the container's child list without
/// knowing about UIStackView / NSStackView / flex container details.
@MainActor public protocol ContainerRenderer: Renderer {
    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView)
    func remove(_ platformView: PlatformView, from container: PlatformView)
    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView)
    func index(of platformView: PlatformView, in container: PlatformView) -> Int?
}

public extension ContainerRenderer {
    /// Default move: remove then reinsert. Renderers whose underlying
    /// container supports a direct move op can override for efficiency.
    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        remove(platformView, from: container)
        insert(platformView, at: index, into: container)
    }
}

// MARK: - ChildrenBuilder

/// Result builder for concise children-list construction in
/// ContainerViews. Enables trailing-closure syntax:
///
///     VStack(spacing: 16) {
///         Text("Hello")
///         Button("Tap") { ... }
///     }
///
/// This is a Swift-specific convenience on top of the canonical
/// `init(children: [any View])` API. Other language implementations
/// of Forge use their own idiomatic patterns (Kotlin trailing
/// lambdas, Dart child lists, etc.); the shape of the underlying
/// data is what stays consistent across platforms.
@resultBuilder
public struct ChildrenBuilder {
    public static func buildExpression(_ view: any View) -> [any View] {
        [view]
    }

    public static func buildBlock(_ components: [any View]...) -> [any View] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [any View]?) -> [any View] {
        component ?? []
    }

    public static func buildEither(first component: [any View]) -> [any View] {
        component
    }

    public static func buildEither(second component: [any View]) -> [any View] {
        component
    }

    public static func buildArray(_ components: [[any View]]) -> [any View] {
        components.flatMap { $0 }
    }
}

// MARK: - ChildBuilder (singular)

/// Result builder that accepts exactly one child view. Use for
/// components that wrap a single piece of content (Button, etc.).
/// Attempting to place two view expressions in the closure is a
/// compile-time error.
@MainActor @resultBuilder
public struct ChildBuilder {
    public static func buildBlock(_ view: any View) -> any View { view }
    public static func buildOptional(_ view: (any View)?) -> any View { view ?? EmptyView() }
    public static func buildEither(first view: any View) -> any View { view }
    public static func buildEither(second view: any View) -> any View { view }
}

// MARK: - EmptyView

/// A zero-size leaf view that renders nothing.
public struct EmptyView: LeafView {
    public init() {}
    public func makeRenderer() -> Renderer { EmptyRenderer() }
}

private final class EmptyRenderer: Renderer {
    func mount() -> PlatformView {
        let view = PlatformView()
        #if canImport(UIKit)
        view.isHidden = true
        #endif
        return view
    }
    func update(_ platformView: PlatformView) {}
}

// MARK: - Identified

/// A view wrapped with an explicit identity, so the reconciler can
/// match it across rebuilds even if its position in a list changes.
/// Created via `SomeView.id(42)` — the resulting IdentifiedView is
/// transparent to everything except the reconciler, which extracts
/// the id for matching.
@MainActor public protocol Identified {
    var id: AnyHashable { get }
    var child: any View { get }
}

public struct IdentifiedView<Inner: View>: View, Identified {
    public let id: AnyHashable
    public let inner: Inner

    public var child: any View { inner }

    public func makeNode() -> Node {
        inner.makeNode()
    }
}

public extension View {
    /// Attach an explicit identity to this view. The reconciler uses
    /// ids for move detection and cross-rebuild identity preservation.
    /// If the same id appears across rebuilds, the underlying Node
    /// (and any state it holds) is preserved, even if the view moved
    /// to a different position in its parent's children list.
    func id(_ id: some Hashable) -> IdentifiedView<Self> {
        IdentifiedView(id: AnyHashable(id), inner: self)
    }
}

// MARK: - Renderer

@MainActor public protocol Renderer: AnyObject {
    /// Create a fresh PlatformView from this renderer's props.
    func mount() -> PlatformView

    /// Apply this renderer's props to an already-mounted PlatformView.
    /// Called during rebuild when the leaf node's type hasn't changed —
    /// preserves PlatformView identity and any native state it carries.
    func update(_ platformView: PlatformView)
}
