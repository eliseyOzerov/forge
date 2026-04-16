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

import Foundation

// MARK: - NavigationItem

/// Per-screen navigation-bar configuration, declared by the hosted
/// view via `.navigation(_:)` and applied to the UIKit `UINavigationItem`
/// by the owning `RouteHostingController`.
///
/// Mirrors the shape of Wave's AppBar widget (title / main / leading /
/// trailing / bottom / background / etc.) so Wave screens port over
/// with minimal adaptation — but backed by UINavigationItem on iOS
/// instead of a custom-rendered bar view. Fields beyond `title` and
/// `hidden` are reserved in the struct but not yet wired through to
/// the native bar; the rendering path will fill in as components
/// need them.
public struct NavigationItem {
    /// Title string. If `main` is also set, `main` wins.
    public var title: String?

    /// Custom title view. Mounted via a sub-Resolver and installed as
    /// `navigationItem.titleView`.
    public var main: (any View)?

    /// Leading bar item. If nil and `hideImplicitBackButton` is false,
    /// the system back button is shown.
    public var leading: (any View)?

    /// Trailing bar item.
    public var trailing: (any View)?

    /// View rendered below the main bar content (search, tabs,
    /// segmented controls). On iOS maps to the scroll-edge accessory
    /// area when available; on older iOS, rendered as a secondary
    /// row within the hosted view.
    public var bottom: (any View)?

    /// Bar background. State-aware (`.scrolledUnder` / `.idle`) —
    /// `.scrolledUnder` maps to `standardAppearance`, `.idle` maps
    /// to `scrollEdgeAppearance`. The Surface can be a solid color,
    /// a Liquid-Glass material (`.glass(...)`), or both composed.
    public var background: StateProperty<Surface>?

    /// Whether the navigation bar is hidden for this route. Applied
    /// via `UINavigationController.setNavigationBarHidden(_:animated:)`.
    public var hidden: Bool

    /// Suppresses the system back button when `leading` is nil.
    public var hideImplicitBackButton: Bool

    /// Override the back action. If set, replaces the system back
    /// button with a custom one that calls this closure on tap.
    /// Typical use: guard against data loss before popping.
    public var onBack: (@MainActor () -> Void)?

    /// Alignment for the main/title slot across the full bar width.
    /// Mirrors `AppBar.mainAlignment`. Only the horizontal component
    /// is consulted — UIKit's title slot is already vertically centered.
    public var alignment: Alignment

    /// Padding around the bar's content.
    public var padding: Padding?

    public init(
        title: String? = nil,
        main: (any View)? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        background: StateProperty<Surface>? = nil,
        hidden: Bool = false,
        hideImplicitBackButton: Bool = false,
        onBack: (@MainActor () -> Void)? = nil,
        alignment: Alignment = .center,
        padding: Padding? = nil
    ) {
        self.title = title
        self.main = main
        self.leading = leading
        self.trailing = trailing
        self.bottom = bottom
        self.background = background
        self.hidden = hidden
        self.hideImplicitBackButton = hideImplicitBackButton
        self.onBack = onBack
        self.alignment = alignment
        self.padding = padding
    }
}

public extension View {
    /// Declare the navigation bar configuration for this view's hosted
    /// screen. Applied to the enclosing `RouteHostingController`'s
    /// `UINavigationItem`. Safe to re-declare on every rebuild — the
    /// hosting controller writes through UIKit property setters, which
    /// are cheap no-ops when values are unchanged.
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
        if let channel = context.maybeWatch(Observable<NavigationItem>.self) {
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

// MARK: - UIKit-backed implementation
//
// Everything above this line is platform-neutral — Route, RouterHandle,
// NavigationItem, DeepLinks, RouteContext, and the BuildContext sugar
// can compile on any Forge platform. Below is the iOS/UIKit-specific
// rendering: the Router view itself, its Model/Builder, and the
// UINavigationController-backed host. Porting to AppKit / Android
// would add parallel sections here.

#if canImport(UIKit)
import UIKit

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
///
/// VC containment: when this view moves to a window, it walks the
/// responder chain to find its containing view controller and
/// installs the navigation controller as its child. That's what
/// makes swipe-back, status-bar style inheritance, keyboard
/// appearance notifications, and rotation callbacks work —
/// UIKit routes those through the VC hierarchy, not the view
/// hierarchy.
final class RouterHostView: UIView {
    private var navController: UINavigationController?
    private weak var model: RouterModel?
    private var hostsByRouteID: [UUID: RouteHostingController] = [:]

    override func layoutSubviews() {
        super.layoutSubviews()
        navController?.view.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let nav = navController else { return }
        if window != nil {
            embedNavAsChildVC(nav)
        } else {
            detachNavFromParentVC(nav)
        }
    }

    private func embedNavAsChildVC(_ nav: UINavigationController) {
        guard nav.parent == nil else { return }
        guard let parent = findParentViewController() else { return }
        // addChild auto-fires willMove(toParent:) on the child.
        parent.addChild(nav)
        // The nav's view is already in our subview hierarchy from
        // attach(model:); complete the containment handshake.
        nav.didMove(toParent: parent)
    }

    private func detachNavFromParentVC(_ nav: UINavigationController) {
        guard nav.parent != nil else { return }
        nav.willMove(toParent: nil)
        nav.removeFromParent()
    }

    /// Walk the responder chain to find the nearest enclosing
    /// UIViewController. Start at `self.next` so the walk climbs
    /// out of this view into whatever view controller owns it.
    private func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = self.next
        while let current = responder {
            if let vc = current as? UIViewController {
                return vc
            }
            responder = current.next
        }
        return nil
    }

    func attach(model: RouterModel) {
        self.model = model
        guard navController == nil else { return }
        // First attach — create the nav controller and do an initial sync.
        let nav = UINavigationController()
        navController = nav
        addSubview(nav.view)
        sync()
        // If we're already in a window at attach time (re-entrant
        // cases), make sure the nav gets embedded. Otherwise
        // didMoveToWindow will handle it on first layout.
        if window != nil {
            embedNavAsChildVC(nav)
        }
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

/// UIViewController that hosts a single Route's body view and mirrors
/// its `.navigation(_:)`-declared NavigationItem onto the native
/// `UINavigationItem`. One controller per Route identity — reused
/// across RouterHost syncs so the hosted view preserves its state.
///
/// View hierarchy owned by this controller:
///
///     self.view (container UIView)
///       stack (UIStackView, vertical)
///         bottomSlotHost      — shows navItem.bottom if any
///         bodyHost            — the route body subtree
///
/// Sub-Resolvers:
///   - bodyResolver     → body (route.body() wrapped with Provideds)
///   - mainResolver     → navItem.main (titleView)
///   - leadingResolver  → navItem.leading  (leftBarButtonItem customView)
///   - trailingResolver → navItem.trailing (rightBarButtonItem customView)
///   - bottomResolver   → navItem.bottom (inside bottomSlotHost)
final class RouteHostingController: UIViewController {
    private(set) var route: Route
    private var routeContext: RouteContext = RouteContext(canPop: false)

    private let bodyResolver = Resolver()
    private let mainResolver = Resolver()
    private let leadingResolver = Resolver()
    private let trailingResolver = Resolver()
    private let bottomResolver = Resolver()

    private var stack: UIStackView!
    private var bottomSlotHost: UIView!
    private var bodyHost: UIView!

    private let navItemObservable = Observable<NavigationItem>(NavigationItem())
    private var navItemSubscription: Subscription?
    private var routerHandle: RouterHandle?

    init(route: Route) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .systemBackground

        stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        bottomSlotHost = UIView()
        bottomSlotHost.isHidden = true
        stack.addArrangedSubview(bottomSlotHost)

        bodyHost = UIView()
        stack.addArrangedSubview(bodyHost)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container

        mountBody()

        apply(navItem: navItemObservable.value)
        navItemSubscription = navItemObservable.observe { [weak self] item in
            self?.apply(navItem: item)
        }
    }

    /// Called by RouterHostView on every sync. Updates the hosted
    /// Route (body closure may have captured new props) AND its
    /// RouteContext (stack position may have changed). Re-syncs the
    /// body subtree in place, preserving Node state where possible.
    func update(route: Route, context: RouteContext) {
        self.route = route
        self.routeContext = context
        if isViewLoaded {
            mountBody()
        }
    }

    /// Installed by RouterHostView at creation time so we can re-
    /// Provide it inside this controller's own Resolver tree.
    func attach(routerHandle: RouterHandle) {
        self.routerHandle = routerHandle
    }

    /// Build the body subtree and mount/update it in place inside
    /// `bodyHost`. Uses `canUpdate` + `update(from:)` where possible
    /// so Model state survives re-syncs; otherwise re-inflates.
    private func mountBody() {
        let wrapped = wrappedBody()
        syncSlot(bodyResolver, host: bodyHost, view: wrapped, fill: true)
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
        self.navigationItem.hidesBackButton = navItem.hideImplicitBackButton

        // Hide/show the nav bar for this route.
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(navItem.hidden, animated: true)
        }

        // Title view — `main` overrides `title` when set.
        self.navigationItem.titleView = syncTitleView(navItem: navItem)

        // Bar button items. BarButton gets a native UIBarButtonItem
        // so it participates in the bar's glass container and morph;
        // any other View is wrapped as customView.
        self.navigationItem.leftBarButtonItem = makeLeftBarItem(navItem: navItem)
        self.navigationItem.rightBarButtonItem = makeTrailingBarItem(view: navItem.trailing)

        // Bottom accessory (rendered below the nav bar, above the body).
        syncBottom(view: navItem.bottom)

        // Per-route nav bar background Surface → UINavigationBarAppearance.
        // `.idle` maps to scrollEdgeAppearance (no content behind),
        // `.scrolledUnder` maps to standardAppearance (content under glass).
        applyBackground(navItem.background)
    }

    /// Mount the `main` view as `navigationItem.titleView`, wrapped
    /// in a Forge `Box` that applies `alignment` and `padding`. We
    /// use Forge's own layout so the bar chrome composes from the
    /// same primitives screens use — UIKit just gives us the slot;
    /// Forge handles the placement inside it.
    private func syncTitleView(navItem: NavigationItem) -> UIView? {
        guard let main = navItem.main else { return nil }
        let wrapped: any View = Box(
            BoxStyle(
                .fillWidth,
                padding: navItem.padding ?? .zero,
                // Only the horizontal component matters inside the
                // title slot — UIKit already vertically centers it.
                alignment: Alignment(navItem.alignment.x, 0)
            )
        ) { main }
        return syncSlot(mainResolver, host: nil, view: wrapped, fill: false)
    }

    /// Build the leading bar-button item. Priority:
    ///   1. `navItem.leading`, if it's a `BarButton` → native item
    ///      (participates in the bar's glass container).
    ///   2. `navItem.leading`, any other View → wrapped as customView.
    ///   3. `navItem.onBack` → synthesize a native BarButton with a
    ///      back-chevron icon.
    ///   4. Otherwise nil (system back button unless suppressed).
    private func makeLeftBarItem(navItem: NavigationItem) -> UIBarButtonItem? {
        if let leadingView = navItem.leading {
            return makeBarItem(resolver: leadingResolver, view: leadingView)
        }
        if let onBack = navItem.onBack {
            let backButton = BarButton(icon: "chevron.backward", onTap: onBack)
            return backButton.makeBarButtonItem()
        }
        return nil
    }

    /// Build the trailing bar-button item from a user-supplied view.
    /// Same priority as leading minus the onBack synthesis.
    private func makeTrailingBarItem(view: (any View)?) -> UIBarButtonItem? {
        guard let view else { return nil }
        return makeBarItem(resolver: trailingResolver, view: view)
    }

    /// Produce a `UIBarButtonItem` from an arbitrary Forge view.
    /// BarButton gets the native path; anything else is mounted via
    /// the given resolver and wrapped as `customView`.
    private func makeBarItem(resolver: Resolver, view: any View) -> UIBarButtonItem? {
        if let native = view as? BarButton {
            return native.makeBarButtonItem()
        }
        guard let mounted = syncSlot(resolver, host: nil, view: view, fill: false) else {
            return nil
        }
        return UIBarButtonItem(customView: mounted)
    }

    /// Apply `navItem.background` to the hosted route's
    /// `UINavigationItem` appearances. Liquid-Glass Surfaces map to
    /// `backgroundEffect`; solid-color Surfaces map to
    /// `backgroundColor`. State split:
    ///   - `.idle` → `scrollEdgeAppearance` (nothing behind the bar)
    ///   - `.scrolledUnder` → `standardAppearance` (content underneath)
    ///
    /// Non-trivial Surfaces (gradients, composed layers) aren't yet
    /// pulled through — they'd need a snapshot-to-UIImage step for
    /// `backgroundImage`. Tracked for a follow-up.
    private func applyBackground(_ property: StateProperty<Surface>?) {
        guard let property else {
            self.navigationItem.standardAppearance = nil
            self.navigationItem.scrollEdgeAppearance = nil
            return
        }
        self.navigationItem.standardAppearance = appearance(from: property(.scrolledUnder))
        self.navigationItem.scrollEdgeAppearance = appearance(from: property(.idle))
    }

    private func appearance(from surface: Surface) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        if let glass = surface.glassStyle {
            // `UINavigationBarAppearance.backgroundEffect` is typed as
            // `UIBlurEffect?`. When the app is built against the iOS
            // 26 SDK, UIKit automatically promotes these system
            // materials to Liquid Glass; on older runtimes, they
            // render as the traditional blur. We map our GlassStyle
            // variants to the closest system material and let the OS
            // do the upgrade.
            appearance.backgroundEffect = blurEffect(for: glass)
        }
        if let color = surface.primaryColor {
            appearance.backgroundColor = color.platformColor
        }
        return appearance
    }

    private func blurEffect(for style: GlassStyle) -> UIBlurEffect {
        switch style {
        case .regular:   return UIBlurEffect(style: .systemMaterial)
        case .prominent: return UIBlurEffect(style: .systemThickMaterial)
        case .clear:     return UIBlurEffect(style: .systemUltraThinMaterial)
        }
    }

    /// Install `view` into `bottomSlotHost` (sized by its own intrinsic
    /// size / layout), or hide the slot when nil.
    private func syncBottom(view: (any View)?) {
        guard let v = view else {
            bottomSlotHost.isHidden = true
            bottomSlotHost.subviews.forEach { $0.removeFromSuperview() }
            return
        }
        _ = syncSlot(bottomResolver, host: bottomSlotHost, view: v, fill: true)
        bottomSlotHost.isHidden = false
    }

    /// Mount-or-update helper that reuses the resolver's existing
    /// root node when possible (preserving Model state across applies)
    /// and falls back to re-inflating on type change. When `host` is
    /// provided and `fill` is true, pins the mounted platform view to
    /// the host's edges.
    @discardableResult
    private func syncSlot(_ resolver: Resolver, host: UIView?, view: any View, fill: Bool) -> UIView? {
        let platform: UIView?
        if let existing = resolver.rootNode, existing.canUpdate(to: view) {
            existing.update(from: view)
            platform = existing.platformView
        } else {
            platform = resolver.mount(view)
        }
        guard let platform, let host else { return platform }

        // (Re)attach to host if needed.
        if platform.superview !== host {
            host.subviews.forEach { $0.removeFromSuperview() }
            host.addSubview(platform)
        }
        if fill {
            platform.translatesAutoresizingMaskIntoConstraints = false
            // Avoid duplicating constraints on subsequent calls — if
            // the view was already pinned, its existing constraints
            // remain valid.
            if platform.constraints.isEmpty || platform.superview !== host {
                NSLayoutConstraint.activate([
                    platform.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    platform.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                    platform.topAnchor.constraint(equalTo: host.topAnchor),
                    platform.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                ])
            }
        }
        return platform
    }

    // Subscription is released alongside `self` when the hosting
    // controller deinits — no explicit cancel needed (and it would
    // trip Swift 6 strict concurrency anyway, since `cancel()` is
    // @MainActor-isolated but `deinit` is nonisolated).
}

#endif
