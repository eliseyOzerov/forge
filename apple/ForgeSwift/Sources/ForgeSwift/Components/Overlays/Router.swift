//
//  Router.swift
//  ForgeSwift
//
//  Router view + its ecosystem:
//
//    - `NavigationItem` / `.navigation(_:)`  — per-screen nav bar config,
//       set by the hosted view, applied to the native UINavigationItem.
//    - `Route`                               — value struct wrapping the
//       view to present, plus optional user key and (internal) result key.
//    - `RouterHandle`                        — plain-class imperative API.
//       Can be created outside the view tree and injected from above.
//    - `DeepLink` / `@DeepLinkBuilder` / `DeepLinkMap`  — URL→Route
//       mapping with a result-builder DSL.
//    - `Router: ModelView`                   — the mounted view. Seeds
//       the handle's stack with an initial "first" route built from a
//       `@ChildBuilder` closure. First is a regular stack entry — user
//       can replace/insert around it — it just can't be popped below.
//    - `RouterHost` (leaf) + UIKit integration backing the UINavigationController.
//    - `BuildContext.router` / `BuildContext.route` — descendants' access.
//
//  Non-screen presentations (sheet/modal/drawer/alert/cover/lightbox) are
//  reserved in Route but not yet plumbed through the host — this file
//  handles screen-style push/pop only for now.
//

#if canImport(UIKit)
import UIKit

// MARK: - NavigationItem

/// The per-screen nav bar configuration a view declares via
/// `.navigation(_:)`. The hosting `RouteHostingController` reads it
/// from an `Observable<NavigationItem>` installed into the route's
/// subtree and applies it to the UIKit `UINavigationItem` it owns.
public struct NavigationItem: Equatable {
    public var title: String?

    public init(title: String? = nil) {
        self.title = title
    }
}

public extension View {
    /// Declare the navigation bar configuration for this view's hosted
    /// screen. Applied to the enclosing `RouteHostingController`'s
    /// `UINavigationItem`. Safe to re-declare on every rebuild — the
    /// channel dedups by equality so no-op updates don't bounce UIKit.
    func navigation(_ item: NavigationItem) -> some View {
        NavigationApplier(item: item, child: self)
    }
}

/// Internal BuiltView that writes `item` into the enclosing route's
/// `Observable<NavigationItem>` channel. No-op if no channel is found
/// (e.g. the view is mounted outside any Router).
struct NavigationApplier: BuiltView {
    let item: NavigationItem
    let child: any View

    func build(context: BuildContext) -> any View {
        if let channel = context.maybeWatch(Observable<NavigationItem>.self),
           channel.value != item {
            channel.value = item
        }
        return child
    }
}

// MARK: - Route

/// A navigation destination — a view to present plus the metadata the
/// Router uses to identify and route to it. Constructed at the push
/// site; not a protocol to conform to.
///
///     Route { ProfileView(id: 42) }
///     Route(key: "inbox") { InboxView() }
///
/// Identity: every Route has a stable `id: UUID` assigned at construction
/// that the Router uses to reuse UIViewControllers across rebuilds.
/// The user-facing `key: AnyHashable?` is for predicate-based operations
/// (`insert(below:)`, `pop(until:)`, etc.) that want to recognize a
/// logical screen without caring about its specific instance.
public struct Route {
    public let id: UUID
    public let key: AnyHashable?
    public let body: @MainActor () -> any View

    /// Set internally by `pushForResult` so the continuation can be
    /// looked up and resumed when this route pops.
    var resultKey: UUID?

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = UUID()
        self.key = key
        self.body = body
        self.resultKey = nil
    }

    /// Internal init used by Router to construct a root route with a
    /// stable, pre-known id (so the root VC is preserved across
    /// Router rebuilds).
    init(
        id: UUID,
        key: AnyHashable? = nil,
        body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.body = body
        self.resultKey = nil
    }
}

// MARK: - Deep links

/// One entry in a `DeepLinkMap`: a URL pattern and a factory that
/// produces a Route from matched parameters. Patterns use `:name` for
/// path-segment captures (e.g. `/profile/:id`).
public struct DeepLink {
    public let pattern: String
    public let factory: @MainActor (URLParams) -> Route?

    public init(
        _ pattern: String,
        factory: @escaping @MainActor (URLParams) -> Route?
    ) {
        self.pattern = pattern
        self.factory = factory
    }
}

/// Parameters extracted from a URL match. Access by name via subscript.
public struct URLParams {
    public let values: [String: String]
    public subscript(key: String) -> String? { values[key] }
}

@resultBuilder
public struct DeepLinkBuilder {
    public static func buildBlock(_ components: DeepLink...) -> [DeepLink] { components }
    public static func buildOptional(_ component: [DeepLink]?) -> [DeepLink] { component ?? [] }
    public static func buildEither(first component: [DeepLink]) -> [DeepLink] { component }
    public static func buildEither(second component: [DeepLink]) -> [DeepLink] { component }
    public static func buildArray(_ components: [[DeepLink]]) -> [DeepLink] { components.flatMap { $0 } }
}

/// The Router's deep-link table. Attach to a Router at construction;
/// resolve with `router.resolve(url:)` at the app boundary
/// (SceneDelegate, UNNotification, etc.).
public struct DeepLinkMap {
    public let links: [DeepLink]

    public init(@DeepLinkBuilder _ build: () -> [DeepLink] = { [] }) {
        self.links = build()
    }

    /// Match a URL against the registered patterns in declaration order.
    /// Returns the first successful factory's Route, or nil if nothing
    /// matches or the factory rejects (returns nil from its closure).
    @MainActor
    public func resolve(_ url: URL) -> Route? {
        for link in links {
            if let params = Self.match(pattern: link.pattern, url: url),
               let route = link.factory(params) {
                return route
            }
        }
        return nil
    }

    /// Match a pattern like `/profile/:id` against a URL's path. Only
    /// handles static segments and `:name` captures in v1 — no query
    /// strings, no nested optionals, no regex.
    static func match(pattern: String, url: URL) -> URLParams? {
        let patternSegments = pattern.split(separator: "/").map(String.init)
        let pathSegments = url.path.split(separator: "/").map(String.init)
        guard patternSegments.count == pathSegments.count else { return nil }

        var params: [String: String] = [:]
        for (p, v) in zip(patternSegments, pathSegments) {
            if p.hasPrefix(":") {
                params[String(p.dropFirst())] = v
            } else if p != v {
                return nil
            }
        }
        return URLParams(values: params)
    }
}

// MARK: - RouterHandle

/// Imperative API for driving a Router. Can be created outside the
/// view tree and injected into a Router's init so code that doesn't
/// live in a BuildContext (app delegates, deep-link callbacks, debug
/// tools) can still navigate.
///
/// Inside the view tree, descendants reach this same instance via
/// `context.router`.
///
/// The handle owns the full stack — including the initial "first"
/// route seeded by the Router. First is a regular entry: it can be
/// replaced, routes can be inserted above or below it — the only
/// constraint is that pop operations never drop the stack below one
/// entry. There is always something visible.
@MainActor public final class RouterHandle {
    /// The full route stack. `stack[0]` is the first (bottom) route;
    /// `stack.last` is the currently visible top. Mutated by the API
    /// methods below; framework should not write to it directly.
    public private(set) var stack: [Route] = []

    /// Framework-internal: called after any stack mutation. The
    /// owning `RouterModel` wires this to a node rebuild.
    var onChange: (() -> Void)?

    /// Continuations awaiting a popped-with-result. Keyed by the
    /// `resultKey` stamped onto a route at pushForResult time. Routes
    /// removed without an explicit result resolve with nil.
    private var pendingResults: [UUID: (Any?) -> Void] = [:]

    public init() {}

    // MARK: Reads

    /// The current top of the stack — the route the user sees. Nil
    /// only before the Router has seeded its first route.
    public var top: Route? { stack.last }

    /// The first (bottom) route — what's visible after `popToFirst`.
    /// Nil only before the Router has seeded the stack.
    public var first: Route? { stack.first }

    /// Whether a `pop()` would succeed. Equivalent to `stack.count > 1`.
    public var canPop: Bool { stack.count > 1 }

    /// Whether any route matches the predicate.
    public func contains(where predicate: (Route) -> Bool) -> Bool {
        stack.contains(where: predicate)
    }

    // MARK: Push

    /// Push a route onto the stack. Fire-and-forget — use
    /// `pushForResult` if you need a value back.
    public func push(_ route: Route) {
        stack.append(route)
        onChange?()
    }

    /// Push a route and suspend until it's popped. Returns the
    /// result value cast to the caller's expected type `R`, or nil if
    /// the route was popped without a result (user swipe-back, programmatic
    /// pop without arg, removal via `remove(where:)` etc.).
    ///
    /// Caller is responsible for the result type matching the popper's
    /// argument — mismatches silently yield nil. A mis-cast is almost
    /// always a bug; consider a named wrapper struct for the result
    /// payload if the screen's callers vary in how they interpret it.
    public func pushForResult<R: Sendable>(_ route: Route) async -> R? {
        await withCheckedContinuation { (continuation: CheckedContinuation<R?, Never>) in
            let resultKey = UUID()
            var tagged = route
            tagged.resultKey = resultKey
            pendingResults[resultKey] = { any in
                continuation.resume(returning: any as? R)
            }
            stack.append(tagged)
            onChange?()
        }
    }

    // MARK: Pop

    /// Pop the top route, optionally delivering a result to any
    /// `pushForResult` caller awaiting that route. No-op if the first
    /// route is the only one in the stack (see `canPop`).
    public func pop(result: Any? = nil) {
        guard canPop else { return }
        let popped = stack.removeLast()
        resolveResult(for: popped, with: result)
        onChange?()
    }

    /// Pop until the predicate matches a route remaining at the top,
    /// or until only the first route is left (equivalent to `popToFirst`
    /// if no match exists above the first). Matching route stays on
    /// the stack. The first route itself can never be popped — even
    /// if it matches the predicate, it just stops there.
    public func pop(until predicate: (Route) -> Bool) {
        while stack.count > 1, let top = stack.last, !predicate(top) {
            let popped = stack.removeLast()
            resolveResult(for: popped, with: nil)
        }
        onChange?()
    }

    /// Pop everything above the first route. First stays visible.
    public func popToFirst() {
        while stack.count > 1 {
            let popped = stack.removeLast()
            resolveResult(for: popped, with: nil)
        }
        onChange?()
    }

    // MARK: Insert / Remove / Replace

    public func insert(at index: Int, route: Route) {
        let clamped = max(0, min(index, stack.count))
        stack.insert(route, at: clamped)
        onChange?()
    }

    /// Insert a route just below the top-most stack entry matching
    /// the predicate (searched top-down). No-op if no match.
    public func insert(below predicate: (Route) -> Bool, route: Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        stack.insert(route, at: idx)
        onChange?()
    }

    /// Insert a route just above the top-most stack entry matching
    /// the predicate (searched top-down). No-op if no match.
    public func insert(above predicate: (Route) -> Bool, route: Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        stack.insert(route, at: idx + 1)
        onChange?()
    }

    /// Remove the first route matching the predicate. No-op if the
    /// removal would leave the stack empty.
    public func remove(where predicate: (Route) -> Bool) {
        guard let idx = stack.firstIndex(where: predicate),
              stack.count > 1 else { return }
        let removed = stack.remove(at: idx)
        resolveResult(for: removed, with: nil)
        onChange?()
    }

    /// Remove the route at `index`. No-op if out of bounds or if the
    /// removal would leave the stack empty.
    public func remove(at index: Int) {
        guard stack.indices.contains(index), stack.count > 1 else { return }
        let removed = stack.remove(at: index)
        resolveResult(for: removed, with: nil)
        onChange?()
    }

    /// Replace the entire stack, including the first route. The new
    /// array must be non-empty — empty input is treated as no-op.
    public func replace(routes: [Route]) {
        guard !routes.isEmpty else { return }
        for route in stack { resolveResult(for: route, with: nil) }
        stack = routes
        onChange?()
    }

    /// Replace only the top-most route. If the stack has only the
    /// first route, this replaces the first.
    public func replaceTop(_ route: Route) {
        guard !stack.isEmpty else {
            stack = [route]
            onChange?()
            return
        }
        let popped = stack.removeLast()
        resolveResult(for: popped, with: nil)
        stack.append(route)
        onChange?()
    }

    // MARK: Deep-link dispatch

    /// Attempt to resolve the URL through the Router's `DeepLinkMap`
    /// and push the resulting route. Returns whether a route matched.
    /// The map is provided by the RouterModel via `attachDeepLinks`.
    @discardableResult
    public func resolve(url: URL) -> Bool {
        guard let route = deepLinks?.resolve(url) else { return false }
        push(route)
        return true
    }

    // MARK: Framework wiring (internal)

    private var deepLinks: DeepLinkMap?

    func attachDeepLinks(_ map: DeepLinkMap) {
        self.deepLinks = map
    }

    /// Framework-internal: replace the full stack silently, without
    /// firing `onChange`. Used by `RouterModel.didInit` to seed the
    /// first route before the change callback is wired up.
    func unsafeSetStack(_ routes: [Route]) {
        stack = routes
    }

    /// Framework-internal: replace `stack[0]` silently. Used by
    /// `RouterModel.didUpdate` to flow new parent props into the
    /// first route's body closure while avoiding a re-render loop
    /// (we're already mid-rebuild).
    func unsafeReplaceFirst(_ route: Route) {
        guard !stack.isEmpty else { return }
        stack[0] = route
    }

    private func resolveResult(for route: Route, with value: Any?) {
        guard let key = route.resultKey,
              let resolver = pendingResults.removeValue(forKey: key) else { return }
        resolver(value)
    }
}

public extension BuildContext {
    /// The nearest enclosing Router's handle. Fatal if no Router is
    /// above this point in the tree — use `maybeRouter` for optional.
    var router: RouterHandle { read(RouterHandle.self) }

    /// Optional access to the ancestor Router's handle.
    var maybeRouter: RouterHandle? { maybeWatch(RouterHandle.self) }

    /// The enclosing Route's context — per-route environment installed
    /// by the hosting controller. Access from inside a routed view's
    /// subtree to read position-dependent info like `canPop`. Fatal
    /// if called outside any Route.
    var route: RouteContext { read(RouteContext.self) }

    /// Optional variant of `route`.
    var maybeRoute: RouteContext? { maybeWatch(RouteContext.self) }
}

// MARK: - RouteContext

/// Per-route environment installed into each mounted Route's subtree
/// via `Provided<RouteContext>`. Descendants read it with
/// `context.route`.
///
/// v1: just `canPop` — extends over time to cover dismiss, presentation
/// progress, state (entering/entered/exiting/exited), etc.
public struct RouteContext {
    /// Whether this route can be popped. False for the first (bottom)
    /// route in the Router's stack; true for anything above it.
    public let canPop: Bool
}

// MARK: - Router view

/// A navigation host backed by a `UINavigationController`. The
/// `@ChildBuilder` closure provides the permanent root view; pushed
/// routes layer on top via the imperative handle.
///
///     Router(deeplinks: DeepLinkMap {
///         DeepLink("/profile/:id") { params in
///             guard let id = params["id"].flatMap(Int.init) else { return nil }
///             return Route { ProfileView(id: id) }
///         }
///     }) {
///         HomeView()
///     }
///
/// Inject a handle from above for out-of-tree navigation (app delegate,
/// deep-link resolvers):
///
///     let handle = RouterHandle()
///     Router(handle: handle) { HomeView() }
///     // ...
///     handle.push(Route { ThreadView(id: 42) })
public struct Router: ModelView {
    public let providedHandle: RouterHandle?
    public let deeplinks: DeepLinkMap
    public let root: any View

    public init(
        handle: RouterHandle? = nil,
        deeplinks: DeepLinkMap = DeepLinkMap(),
        @ChildBuilder root: () -> any View
    ) {
        self.providedHandle = handle
        self.deeplinks = deeplinks
        self.root = root()
    }

    public func model(context: BuildContext) -> RouterModel {
        RouterModel(
            context: context,
            handle: providedHandle ?? RouterHandle(),
            deeplinks: deeplinks
        )
    }

    public func builder(model: RouterModel) -> RouterBuilder {
        RouterBuilder(model: model)
    }
}

// MARK: - RouterModel

public final class RouterModel: ViewModel<Router> {
    public let handle: RouterHandle

    /// Stable id for the initial first-route so the Router can keep
    /// its view controller across rebuilds AND so `didUpdate` can
    /// recognize whether the user has since replaced the first.
    let firstRouteID = UUID()

    init(context: BuildContext, handle: RouterHandle, deeplinks: DeepLinkMap) {
        self.handle = handle
        super.init(context: context)
        handle.attachDeepLinks(deeplinks)
    }

    public override func didInit(view: Router) {
        super.didInit(view: view)
        // Seed the handle's stack with the initial first route IF it's
        // empty. If the user reused a handle that already has routes,
        // leave it alone — they've already set their own first.
        if handle.stack.isEmpty {
            let firstView = view.root
            handle.unsafeSetStack([
                Route(id: firstRouteID) { firstView }
            ])
        }
        // Wire up the handle's change callback so any mutation from
        // outside the view tree (or from descendant call sites) marks
        // this node dirty and triggers a re-sync of the UINavigationController.
        handle.onChange = { [weak self] in
            self?.rebuild {}
        }
    }

    public override func didUpdate(newView: Router) {
        super.didUpdate(newView: newView)
        // If the stack still has the original first route (same id),
        // update its body closure so new props from the parent flow in.
        // If the user has replaced the first (different id at position 0),
        // don't stomp — their replacement wins.
        if !handle.stack.isEmpty, handle.stack[0].id == firstRouteID {
            let firstView = newView.root
            handle.unsafeReplaceFirst(
                Route(id: firstRouteID) { firstView }
            )
        }
    }

    public override func didDispose() {
        handle.onChange = nil
    }
}

// MARK: - RouterBuilder

public final class RouterBuilder: ViewBuilder<RouterModel> {
    public override func build(context: BuildContext) -> any View {
        // Make the handle available to descendants. Provided wraps the
        // RouterHost so `context.router` inside any pushed route can
        // reach this handle. (Each route's body is mounted inside the
        // route's own Resolver — see RouteHostingController — so we
        // separately re-install the handle there.)
        Provided(model.handle) {
            RouterHost(model: model)
        }
    }
}

// MARK: - RouterHost (leaf wrapping the UINavigationController)

struct RouterHost: LeafView {
    let model: RouterModel

    func makeRenderer() -> Renderer {
        RouterHostRenderer(model: model)
    }
}

final class RouterHostRenderer: Renderer {
    let model: RouterModel

    init(model: RouterModel) {
        self.model = model
    }

    func mount() -> PlatformView {
        let view = RouterHostView()
        view.attach(model: model)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? RouterHostView else { return }
        view.attach(model: model)
        view.sync()
    }
}

/// UIView wrapper that owns a UINavigationController and syncs its
/// viewControllers array from the RouterModel's stack. Creates one
/// `RouteHostingController` per route, reusing across rebuilds keyed
/// by Route.id so pushed screens preserve their state.
final class RouterHostView: UIView {
    private var navController: UINavigationController?
    private weak var model: RouterModel?
    private var hostsByRouteID: [UUID: RouteHostingController] = [:]

    override func layoutSubviews() {
        super.layoutSubviews()
        navController?.view.frame = bounds
    }

    func attach(model: RouterModel) {
        self.model = model
        guard navController == nil else { return }
        // First attach — create the nav controller and do an initial sync.
        let nav = UINavigationController()
        navController = nav
        addSubview(nav.view)
        sync()
    }

    func sync() {
        guard let nav = navController, let model else { return }

        // Build the target VC list by walking handle.stack. The first
        // route (stack[0]) is just another entry — it gets a VC like
        // any pushed route, reused across syncs by Route.id. Its
        // RouteContext reports `canPop: false`.
        var targetVCs: [UIViewController] = []
        var seenIDs: Set<UUID> = []
        for (index, route) in model.handle.stack.enumerated() {
            seenIDs.insert(route.id)
            let vc = hostsByRouteID[route.id] ?? makeHost(for: route, handle: model.handle)
            let context = RouteContext(canPop: index > 0)
            vc.update(route: route, context: context)
            hostsByRouteID[route.id] = vc
            targetVCs.append(vc)
        }

        // Drop hosting controllers for routes no longer in the stack —
        // the VCs they held are about to be popped off the nav stack
        // anyway; releasing the entry lets them deinit.
        hostsByRouteID = hostsByRouteID.filter { seenIDs.contains($0.key) }

        // Animate only when we already have a stack (not on initial mount).
        let animated = !nav.viewControllers.isEmpty
        nav.setViewControllers(targetVCs, animated: animated)
    }

    private func makeHost(for route: Route, handle: RouterHandle) -> RouteHostingController {
        let vc = RouteHostingController(route: route)
        vc.attach(routerHandle: handle)
        return vc
    }
}

// MARK: - RouteHostingController

/// UIViewController that hosts a single Route's body view in its own
/// sub-Resolver and mirrors its `.navigation(_:)`-declared NavigationItem
/// onto the native UINavigationItem. One controller per Route identity —
/// reused across RouterHost syncs so the hosted view preserves its state.
final class RouteHostingController: UIViewController {
    private(set) var route: Route
    private var routeContext: RouteContext = RouteContext(canPop: false)
    private let resolver = Resolver()
    private let navItemObservable = Observable<NavigationItem>(NavigationItem())
    private var navItemSubscription: Subscription?
    private var routerHandle: RouterHandle?

    init(route: Route) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = resolver.mount(wrappedBody())
        apply(navItem: navItemObservable.value)
        navItemSubscription = navItemObservable.observe { [weak self] item in
            self?.apply(navItem: item)
        }
    }

    /// Called by RouterHostView on every sync. Updates the hosted
    /// Route (body closure may have captured new props) AND its
    /// RouteContext (stack position may have changed). Re-runs the
    /// subtree through the resolver to pick both up.
    func update(route: Route, context: RouteContext) {
        self.route = route
        self.routeContext = context
        if isViewLoaded {
            _ = resolver.mount(wrappedBody())
        }
    }

    /// Installed by RouterHostView at creation time so we can re-
    /// Provide it inside this controller's own Resolver tree.
    func attach(routerHandle: RouterHandle) {
        self.routerHandle = routerHandle
    }

    /// Build the view subtree this controller mounts — wraps the
    /// Route's body in three Provided layers: RouterHandle (so
    /// descendants can call `ctx.router` from any pushed route's
    /// isolated sub-Resolver tree), the navigation-item observable
    /// (so `.navigation(_:)` can write into it), and the per-route
    /// `RouteContext` (so descendants can read `ctx.route.canPop`).
    private func wrappedBody() -> any View {
        let handle = routerHandle
        let body = route.body
        let context = routeContext
        return Buildable { _ in
            var content: any View = body()
            content = Provided(context) { content }
            content = Provided(self.navItemObservable) { content }
            if let handle {
                content = Provided(handle) { content }
            }
            return content
        }
    }

    private func apply(navItem: NavigationItem) {
        self.title = navItem.title
        // Future: bar button items, large title style, back button
        // customization, etc.
    }

    // Subscription is released alongside `self` when the hosting
    // controller deinits — no explicit cancel needed (and it would
    // trip Swift 6 strict concurrency anyway, since `cancel()` is
    // @MainActor-isolated but `deinit` is nonisolated).
}

#endif
