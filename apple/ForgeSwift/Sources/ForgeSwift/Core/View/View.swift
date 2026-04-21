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
//  A View is either Leaf or composite. Stateless composites conform
//  to BuiltView and implement build(context:) directly. Stateful
//  composites conform to ModelView — the framework routes their build
//  through a Builder created via makeBuilder(), with a Model created
//  via makeModel(context:) holding the persistent state. BuiltView
//  and ModelView are siblings under View; neither inherits from the
//  other. Their backing Nodes are split accordingly: BuiltNode for
//  BuiltView (no Model slot, no user-triggered rebuild path) and
//  ModelNode for ModelView (owns Model/Builder and dispatches lifecycle).
//

/// Fundamental view protocol; every Forge view returns a Node via `makeNode()`.
@MainActor public protocol View {
    func makeNode() -> Node
}

// MARK: - Leaf

/// View that renders a platform view via a Renderer.
@MainActor public protocol LeafView: View {
    func makeRenderer() -> Renderer
}

public extension LeafView {
    func makeNode() -> Node { LeafNode() }
}

// MARK: - Built

/// A stateless composite: a View whose body is built from a single
/// `build(context:)` function. Backed by `BuiltNode`, which holds no
/// per-instance data and has no user-triggered rebuild path. It can
/// still be dirtied by upstream observable emissions (Provided
/// changes, `context.watch`), which re-runs its build.
@MainActor public protocol BuiltView: View {
    func build(context: ViewContext) -> any View
}

public extension BuiltView {
    func makeNode() -> Node { BuiltNode() }
}

/// A stateful composite: a View backed by a persistent `Model` and
/// a per-render `Builder`. The framework creates the Model once at
/// mount via `model(context:)`, creates a fresh Builder each render
/// via `builder(model:)`, and calls the Builder's `build(context:)`
/// to produce the subtree. Backed by `ModelNode`, which owns the
/// Model slot, the dirty flag, and dispatches lifecycle (`didInit`,
/// `didUpdate`, `didRebuild`, `didDispose`).
///
/// The associated type constraints refer to the lifecycle *protocols*
/// (`ViewLifecycle`, `ViewBuilding`). In practice most conformers
/// inherit from the default base classes (`ViewModel<Self>`,
/// `ViewBuilder<Model>`) which provide context capture, view stashing,
/// and a rebuild helper — but a user can also conform to the
/// protocols directly for testability or special cases.
@MainActor public protocol ModelView: View {
    associatedtype Model: ViewLifecycle<Self>
    associatedtype Builder: ViewBuilding<Model>
    func model(context: ViewContext) -> Model
    func builder(model: Model) -> Builder
}

public extension ModelView {
    func makeNode() -> Node { ModelNode() }
}

// MARK: - ViewLifecycle (protocol) + ViewModel (default class)

/// Lifecycle contract for a ModelView's persistent state container.
/// All requirements are default-empty — conformers override only the
/// hooks they need. This protocol declares the dispatch surface the
/// framework uses on the owning `ModelNode`.
///
/// Most users don't conform to this protocol directly — they subclass
/// the `ViewModel<View>` default class, which handles context
/// capture, view stashing, and the `rebuild { }` helper. Conform
/// directly when you need full control (e.g. a model backed by a
/// non-class type, or a test double with custom lifecycle behavior).
@MainActor public protocol ViewLifecycle<View>: AnyObject {
    associatedtype View

    /// Called once after the Model is created, before the first build.
    func didInit(view: View)

    /// Called when the parent rebuilds with a new `View` value for
    /// this model's slot. Fired before the Builder runs for that
    /// render pass. Conformers that need the previous view can access
    /// it via their own stashed property (or via `self.view` on the
    /// `ViewModel` default class, which still holds the previous
    /// value until `super.didUpdate(newView:)` assigns the new one).
    func didUpdate(newView: View)

    /// Called after each render of the owning ModelNode completes.
    func didRebuild()

    /// Called once at unmount, before the Model is discarded. Cleanup
    /// hook for subscriptions, timers, and anything else the Model
    /// owns that outlives a single render.
    func didDispose()
}

public extension ViewLifecycle {
    func didInit(view: View) {}
    func didUpdate(newView: View) {}
    func didRebuild() {}
    func didDispose() {}
}

/// Default base class for a ModelView's Model. Captures the
/// BuildContext at construction, auto-stashes the view in
/// `didInit` / `didUpdate`, and exposes a `rebuild { }` helper that
/// forwards to the context. Subclass this to get the convenience
/// path; conform to `ViewLifecycle` directly if you need full
/// control.
///
///     final class CounterModel: ViewModel<Counter> {
///         var count = 0
///         func increment() { rebuild { count += 1 } }
///     }
///
/// Subclasses that override `didInit` / `didUpdate` should call
/// `super` to preserve the view-stash behavior (unless they stash
/// it themselves).
@MainActor open class ViewModel<View>: ViewLifecycle {
    public let context: ViewContext
    public private(set) var view: View!

    public init(context: ViewContext) {
        self.context = context
    }

    open func didInit(view: View) {
        self.view = view
        autoWatchObservables()
    }

    /// Discover all Observable properties via Mirror and subscribe
    /// to them automatically. No manual watch() needed for @Observable.
    private func autoWatchObservables() {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let listenable = child.value as? Listenable {
                let sub = listenable.listen { [weak self] in
                    self?.rebuild {}
                }
                subscriptions.append(sub)
            }
        }
    }

    open func didUpdate(newView: View) {
        self.view = newView
    }

    open func didRebuild() {}

    open func didDispose() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
    }

    /// Sandwich-style rebuild. Equivalent to `context.rebuild { ... }`,
    /// provided so subclass methods read naturally: `rebuild { count += 1 }`.
    public func rebuild(_ mutation: () -> Void) {
        context.rebuild(mutation)
    }

    private var subscriptions: [Subscription] = []

    /// Subscribe to an observable and rebuild automatically when it
    /// changes. The subscription is cancelled on dispose.
    public func watch<T>(_ observable: Observable<T>) {
        let sub = observable.listen { [weak self] in
            self?.rebuild {}
        }
        subscriptions.append(sub)
    }
}

// MARK: - ViewBuilding (protocol) + ViewBuilder (default class)

/// Build contract for a ModelView's per-render builder. The only
/// requirement is `build(context:) -> any View`; the Model is an
/// associated type that identifies what the builder renders against.
/// Most users subclass the `ViewBuilder<Model>` default class to get
/// the stored-model init for free.
@MainActor public protocol ViewBuilding<Model> {
    associatedtype Model
    func build(context: ViewContext) -> any View
}

/// Default base class for a ModelView's Builder. Holds the Model as
/// a stored property and provides the `init(model:)` the framework
/// uses. Subclass and override `build(context:)`.
///
///     final class CounterBuilder: ViewBuilder<CounterModel> {
///         override func build(context: BuildContext) -> any View {
///             Text("\(model.count)")
///         }
///     }
///
/// Conform to `ViewBuilding` directly if you need full control
/// (e.g. a struct Builder, or one that takes additional init args).
@MainActor open class ViewBuilder<Model>: ViewBuilding {
    public let model: Model

    public init(model: Model) {
        self.model = model
    }

    open func build(context: ViewContext) -> any View {
        fatalError("ViewBuilder subclass must override build(context:)")
    }
}

// MARK: - ViewContext

/// The contract a builder/Model holds onto to interact with the
/// framework: subscribe to observables, trigger rebuilds, look up
/// Provided values. Implemented by `Node` — when the framework
/// calls `build(context:)` or `model(context:)`, it passes the
/// owning node, typed as `ViewContext` so consumers only see the
/// documented surface and not Node's internals.
///
/// Lookup methods split along a read/watch axis:
///
/// - `read(_:)` / `maybeRead(_:)` — one-shot value lookup. Doesn't
///   subscribe anything. Use when you just need the current value
///   (e.g. grabbing a handle to store). Safe to call inside
///   modifiers that also write to the same observable — no feedback
///   loop.
/// - `watch(_:)` / `maybeWatch(_:)` — subscribes the current build
///   pass to slot replacement and, if the value conforms to
///   `Listenable`, to its in-place mutations. Use when the
///   screen should rebuild when the value changes.
@MainActor public protocol ViewContext {
    /// Read an Observable's current value and subscribe this build
    /// pass to its changes.
    func watch<T>(_ observable: Observable<T>) -> T

    /// Flutter-style setState. Runs the mutation closure synchronously,
    /// then marks the owning node dirty — which schedules a rebuild
    /// on the next main-actor tick.
    func rebuild(_ mutation: () -> Void)

    /// One-shot read of the nearest ancestor's `Provided<T>` value.
    /// No subscriptions. Fatal if no provider is found — use
    /// `maybeRead` for optional access.
    func read<T>(_ type: T.Type) -> T

    /// Optional one-shot read. Returns nil if no ancestor provides T.
    /// No subscriptions.
    func tryRead<T>(_ type: T.Type) -> T?

    /// Read the nearest `Provided<T>` and subscribe this build pass
    /// to slot replacement AND (if the value is `Listenable`) to
    /// its in-place mutations. Fatal if no provider is found.
    func watch<T>(_ type: T.Type) -> T

    /// Optional watch. Same subscription semantics as `watch`.
    func tryWatch<T>(_ type: T.Type) -> T?
}

// MARK: - Buildable

/// A BuiltView whose entire body is a single closure. Use for
/// inline subtrees that need a BuildContext — typically to read a
/// Provided value — without defining a dedicated type.
///
///     Buildable { ctx in
///         let theme = ctx.watch(ColorTheme.self)
///         return Text("hi", color: theme.label)
///     }
public struct Buildable: BuiltView {
    private let body: @MainActor (ViewContext) -> any View

    public init(_ body: @escaping @MainActor (ViewContext) -> any View) {
        self.body = body
    }

    public func build(context: ViewContext) -> any View {
        body(context)
    }
}

// MARK: - Observing

/// A BuiltView that watches an Observable and rebuilds its content
/// whenever the value changes. Convenience for the common pattern
/// of subscribing to a single observable value.
///
///     Observing(counter) { value in
///         Text("Count: \(value)")
///     }
public struct Observing<T>: BuiltView {
    private let observable: Observable<T>
    private let content: @MainActor (T) -> any View

    public init(_ observable: Observable<T>, content: @escaping @MainActor (T) -> any View) {
        self.observable = observable
        self.content = content
    }

    public func build(context: ViewContext) -> any View {
        let value = context.watch(observable)
        return content(value)
    }
}

// MARK: - Offstage

/// Keeps its child mounted in the node tree (preserving state) but
/// hidden and excluded from layout when `offstage` is true. When
/// `offstage` is false the child renders and lays out normally.
///
/// Used by Router to keep pushed-but-not-visible routes alive
/// without rebuilding them or including them in layout.
///
///     Offstage(offstage: !isVisible) {
///         ExpensiveView()
///     }
public struct Offstage: View {
    public let offstage: Bool
    public let child: any View

    public init(offstage: Bool = true, @ChildBuilder child: () -> any View) {
        self.offstage = offstage
        self.child = child()
    }

    public func makeNode() -> Node {
        #if canImport(UIKit)
        OffstageNode()
        #else
        fatalError("Offstage not yet implemented for this platform")
        #endif
    }
}

// MARK: - Proxy

/// A single-child wrapper with a custom platform view. Like
/// ContainerView but for exactly one child — no insert/remove/move.
/// The child is properly parented in the node tree.
@MainActor public protocol ProxyView: View {
    var child: any View { get }
    /// When true, ProxyNode skips child reconciliation in update —
    /// the renderer manages the child lifecycle via reconcileChild().
    var deferred: Bool { get }
    func makeRenderer() -> ProxyRenderer
}

public extension ProxyView {
    var deferred: Bool { false }
}

public extension ProxyView {
    func makeNode() -> Node { ProxyNode() }
}

/// Renderer for ProxyView. Has a weak reference back to its owning
/// ProxyNode so platform views can trigger child re-inflation
/// (e.g. LayoutReader on size change).
@MainActor public protocol ProxyRenderer: Renderer {
    var node: ProxyNode? { get set }
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

// MARK: - ListBuilder

/// Generic result builder that collects items into an array.
/// Used for view children, transform sequences, or any list.
@resultBuilder
public struct ListBuilder<T> {
    public static func buildExpression(_ item: T) -> [T] { [item] }
    public static func buildBlock(_ components: [T]...) -> [T] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [T]?) -> [T] { component ?? [] }
    public static func buildEither(first component: [T]) -> [T] { component }
    public static func buildEither(second component: [T]) -> [T] { component }
    public static func buildArray(_ components: [[T]]) -> [T] { components.flatMap { $0 } }
}

/// Convenience: ListBuilder specialized for views.
public typealias ChildrenBuilder = ListBuilder<any View>

/// Convenience: ValueBuilder specialized for a single child view.
public typealias ChildBuilder = ValueBuilder

// MARK: - ValueBuilder (singular)

/// Result builder that accepts exactly one child view. Use for
/// components that wrap a single piece of content (Button, etc.).
/// Attempting to place two view expressions in the closure is a
/// compile-time error.
@MainActor @resultBuilder
public struct ValueBuilder {
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

// MARK: - AnyView

/// Type-erased View. Forwards `makeNode()` to the wrapped view.
public struct AnyView: View {
    public let wrapped: any View

    public init(_ view: any View) {
        self.wrapped = view
    }

    public func makeNode() -> Node {
        wrapped.makeNode()
    }
}

/// View wrapper that attaches a stable identity for reconciliation.
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

/// Platform renderer that mounts and updates a leaf view's native view.
@MainActor public protocol Renderer: AnyObject {
    /// Create and return this renderer's PlatformView. Called once at
    /// mount. The renderer should store a reference to the view it
    /// creates so it can apply updates directly.
    func mount() -> PlatformView

    /// Apply new props from the given View to the already-mounted
    /// platform view. The renderer casts to its concrete View type
    /// internally, diffs against stored state, and selectively
    /// updates the platform view and invalidates layout.
    func update(from view: any View)
}

public extension Renderer {
    func update(from view: any View) {}
}
