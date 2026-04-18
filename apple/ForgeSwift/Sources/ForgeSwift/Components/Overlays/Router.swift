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

// MARK: - Route

/// A navigation destination and its own ModelView. Constructed at
/// the push site; the Router builds Route instances directly.
///
///     Route { ProfileView(id: 42) }
///     Route(key: "inbox") { InboxView() }
///
/// Identity: every Route has a stable `id: UUID` assigned at
/// construction. The reconciler uses `.id(route.id)` to preserve
/// the RouteModel (and all descendant state) across rebuilds.
/// The user-facing `key` is for predicate-based operations
/// (`insert(below:)`, `pop(until:)`, etc.).
public struct Route: ModelView {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = UUID()
        self.key = key
        self.content = body
    }

    /// Internal init used by Router to construct a root route with a
    /// stable, pre-known id.
    init(
        id: UUID,
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }

    public func model(context: ViewContext) -> RouteModel {
        RouteModel(context: context)
    }

    public func builder(model: RouteModel) -> RouteBuilder {
        RouteBuilder(model: model)
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

// MARK: - RouterHandleDelegate

/// Handle-to-owner contract. The handle is a pure dispatch surface:
/// it owns no state, every method forwards to its delegate. The
/// owning `RouterModel` is the delegate, which holds the stack, the
/// pending-result continuations, the deep-link table, and implements
/// all of the navigation operations.
///
/// This separation means the handle stays cheap to construct, can be
/// handed around freely (to code outside the view tree, to tests
/// with a custom delegate, etc.) without dragging along any runtime
/// state. Tests can drop in a mock delegate that records calls
/// without booting the full view pipeline.
@MainActor public protocol RouterHandleDelegate: AnyObject {
    /// Current route stack. `stack[0]` is the first (bottom) route;
    /// `stack.last` is the top. Read-only from the handle's side.
    var stack: [Route] { get }

    func push(_ route: Route)
    func pushForResult<R: Sendable>(_ route: Route) async -> R?
    func pop(result: Any?)
    func pop(until predicate: (Route) -> Bool)
    func popToFirst()
    func insert(at index: Int, route: Route)
    func insert(below predicate: (Route) -> Bool, route: Route)
    func insert(above predicate: (Route) -> Bool, route: Route)
    func remove(where predicate: (Route) -> Bool)
    func remove(at index: Int)
    func replace(routes: [Route])
    func replaceTop(_ route: Route)
    func resolve(url: URL) -> Bool
}

// MARK: - RouterHandle

/// Imperative API for driving a Router. Can be created outside the
/// view tree and injected into a Router's init; descendants reach
/// the same instance via `context.router`.
///
/// The handle itself is stateless — it forwards every call to its
/// delegate (the owning `RouterModel`). Operations issued before a
/// delegate is attached (e.g. against a handle that's been created
/// but not yet mounted) are silent no-ops.
@MainActor public final class RouterHandle {
    /// The delegate that backs this handle's operations. Set by the
    /// owning `RouterModel` in `didInit(view:)`; weak so the handle
    /// doesn't keep the model alive. Calls on the handle before the
    /// delegate is set are silent no-ops.
    public weak var delegate: RouterHandleDelegate?

    public init() {}

    // MARK: Reads

    /// The full route stack — forwarded from the delegate, or empty
    /// if no delegate is attached yet.
    public var stack: [Route] { delegate?.stack ?? [] }

    /// The current top of the stack — the route the user sees. Nil
    /// before a delegate has seeded its first route.
    public var top: Route? { stack.last }

    /// The first (bottom) route — what's visible after `popToFirst`.
    /// Nil before a delegate has seeded the stack.
    public var first: Route? { stack.first }

    /// Whether a `pop()` would succeed. Equivalent to `stack.count > 1`.
    public var canPop: Bool { stack.count > 1 }

    /// Whether any route matches the predicate.
    public func contains(where predicate: (Route) -> Bool) -> Bool {
        stack.contains(where: predicate)
    }

    // MARK: Writes

    /// Push a route onto the stack. Fire-and-forget — use
    /// `pushForResult` if you need a value back.
    public func push(_ route: Route) {
        delegate?.push(route)
    }

    /// Push a route and suspend until it's popped. Returns the result
    /// value cast to the caller's expected type `R`, or nil if the
    /// route was popped without a result (user swipe-back, programmatic
    /// pop without arg, removal via `remove(where:)` etc., or no
    /// delegate attached).
    ///
    /// Caller is responsible for the result type matching the popper's
    /// argument — mismatches silently yield nil. A mis-cast is almost
    /// always a bug; consider a named wrapper struct for the result
    /// payload if the screen's callers vary in how they interpret it.
    public func pushForResult<R: Sendable>(_ route: Route) async -> R? {
        guard let delegate else { return nil }
        return await delegate.pushForResult(route)
    }

    /// Pop the top route, optionally delivering a result to any
    /// `pushForResult` caller awaiting that route. No-op if the first
    /// route is the only one in the stack (see `canPop`).
    public func pop(result: Any? = nil) {
        delegate?.pop(result: result)
    }

    /// Pop until the predicate matches a route remaining at the top,
    /// or until only the first route is left. Matching route stays on
    /// the stack. The first route itself can never be popped.
    public func pop(until predicate: (Route) -> Bool) {
        delegate?.pop(until: predicate)
    }

    /// Pop everything above the first route. First stays visible.
    public func popToFirst() {
        delegate?.popToFirst()
    }

    public func insert(at index: Int, route: Route) {
        delegate?.insert(at: index, route: route)
    }

    /// Insert a route just below the top-most stack entry matching
    /// the predicate (searched top-down). No-op if no match.
    public func insert(below predicate: (Route) -> Bool, route: Route) {
        delegate?.insert(below: predicate, route: route)
    }

    /// Insert a route just above the top-most stack entry matching
    /// the predicate (searched top-down). No-op if no match.
    public func insert(above predicate: (Route) -> Bool, route: Route) {
        delegate?.insert(above: predicate, route: route)
    }

    /// Remove the first route matching the predicate. No-op if the
    /// removal would leave the stack empty.
    public func remove(where predicate: (Route) -> Bool) {
        delegate?.remove(where: predicate)
    }

    /// Remove the route at `index`. No-op if out of bounds or if the
    /// removal would leave the stack empty.
    public func remove(at index: Int) {
        delegate?.remove(at: index)
    }

    /// Replace the entire stack, including the first route. The new
    /// array must be non-empty — empty input is treated as no-op.
    public func replace(routes: [Route]) {
        delegate?.replace(routes: routes)
    }

    /// Replace only the top-most route. If the stack has only the
    /// first route, this replaces the first.
    public func replaceTop(_ route: Route) {
        delegate?.replaceTop(route)
    }

    /// Attempt to resolve the URL through the delegate's registered
    /// deep-link map and push the resulting route. Returns whether a
    /// route matched.
    @discardableResult
    public func resolve(url: URL) -> Bool {
        delegate?.resolve(url: url) ?? false
    }
}

public extension ViewContext {
    /// The nearest enclosing Router's handle.
    var router: RouterHandle { read(RouterHandle.self) }

    /// Optional access to the ancestor Router's handle.
    var maybeRouter: RouterHandle? { tryRead(RouterHandle.self) }

    /// The enclosing Route's handle — per-route state provided by
    /// the Router. Provides phase, progress, dismiss, and position info.
    var route: RouteHandle { read(RouteHandle.self) }

    /// Optional variant of `route`.
    var maybeRoute: RouteHandle? { tryRead(RouteHandle.self) }
}

// MARK: - RoutePhase

/// The lifecycle phase of a route in the stack.
public enum RoutePhase: Equatable, Sendable {
    /// Route is animating in (push). `progress` goes 0→1.
    case entering
    /// Route is fully visible and interactive.
    case settled
    /// Route is animating out (pop). `progress` goes 1→0.
    case exiting
}

// MARK: - RouteHandle

/// Per-route handle provided to each route's subtree. Exposes
/// lifecycle state (phase, progress), position info (index, isTop,
/// isBottom), and a dismiss method. Progress is settable for
/// interactive gestures (e.g. swipe-to-dismiss).
@MainActor public protocol RouteHandle: AnyObject {
    var id: UUID { get }
    var index: Int { get }
    var phase: RoutePhase { get }
    var progress: Double { get set }
    var isTop: Bool { get }
    var isBottom: Bool { get }
    var canPop: Bool { get }
    func dismiss(result: Any?, animated: Bool)
}

public extension RouteHandle {
    func dismiss(animated: Bool = true) {
        dismiss(result: nil, animated: animated)
    }
}

// MARK: - RouteModel

/// Per-route model conforming to RouteHandle. Created once per Route
/// by ModelNode and preserved across rebuilds. Derives position info
/// from the RouterModel's stack on demand.
public final class RouteModel: ViewModel<Route>, RouteHandle {
    public var phase: RoutePhase = .settled
    public var progress: Double = 1.0

    private var router: RouterModel? {
        context.tryRead(RouterModel.self)
    }

    public var id: UUID { view.id }

    public var index: Int {
        router?.stack.firstIndex(where: { $0.id == view.id }) ?? 0
    }

    public var isTop: Bool {
        router?.stack.last?.id == view.id
    }

    public var isBottom: Bool {
        router?.stack.first?.id == view.id
    }

    public var canPop: Bool { index > 0 }

    public func dismiss(result: Any? = nil, animated: Bool = true) {
        let routeID = view.id
        router?.remove(where: { $0.id == routeID })
    }
}

// MARK: - RouteBuilder

public final class RouteBuilder: ViewBuilder<RouteModel> {
    public override func build(context: ViewContext) -> any View {
        let route = model.view!
        let router = context.tryRead(RouterModel.self)
        let navItemObs = router?.navItem(for: route.id)

        if let navItemObs {
            return Provided(model as RouteHandle, navItemObs) {
                route.content()
            }
        }
        return Provided(model as RouteHandle) {
            route.content()
        }
    }
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

    public func model(context: ViewContext) -> RouterModel {
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

public final class RouterModel: ViewModel<Router>, RouterHandleDelegate {
    public let handle: RouterHandle
    public private(set) var stack: [Route] = []

    /// Per-route nav item observables, keyed by route id.
    var navItems: [UUID: Observable<NavigationItem>] = [:]


    /// Stable id for the initial first-route so the Router can keep
    /// its view controller across rebuilds AND so `didUpdate` can
    /// recognize whether the user has since replaced the first.
    let firstRouteID = UUID()


    private var pendingResults: [UUID: (Any?) -> Void] = [:]
    private let deepLinks: DeepLinkMap

    /// Get or create the nav item observable for a route.
    func navItem(for routeID: UUID) -> Observable<NavigationItem> {
        if let existing = navItems[routeID] { return existing }
        let obs = Observable(NavigationItem())
        navItems[routeID] = obs
        return obs
    }


    init(context: ViewContext, handle: RouterHandle, deeplinks: DeepLinkMap) {
        self.handle = handle
        self.deepLinks = deeplinks
        super.init(context: context)
    }

    public override func didInit(view: Router) {
        super.didInit(view: view)
        if stack.isEmpty {
            let firstView = view.root
            stack = [Route(id: firstRouteID) { firstView }]
        }
        handle.delegate = self
    }

    public override func didUpdate(newView: Router) {
        super.didUpdate(newView: newView)
        // Parent rebuilt with a new Router value — stack[0]'s body
        // closure may have captured new props. Refresh it in place
        // (same id, new closure). If the user has since replaced the
        // first with a different route, leave it alone.
        if !stack.isEmpty, stack[0].id == firstRouteID {
            let firstView = newView.root
            stack[0] = Route(id: firstRouteID) { firstView }
        }
    }

    public override func didDispose() {
        if handle.delegate === self { handle.delegate = nil }
    }

    // MARK: - RouterHandleDelegate — mutation ops dispatch direct

    public func push(_ route: Route) {
        rebuild { stack.append(route) }
    }

    public func pushForResult<R: Sendable>(_ route: Route) async -> R? {
        await withCheckedContinuation { (continuation: CheckedContinuation<R?, Never>) in
            pendingResults[route.id] = { any in
                continuation.resume(returning: any as? R)
            }
            rebuild { stack.append(route) }
        }
    }

    public func pop(result: Any? = nil) {
        guard stack.count > 1 else { return }
        rebuild {
            let popped = stack.removeLast()
            resolveResult(for: popped, with: result)
        }
    }

    public func pop(until predicate: (Route) -> Bool) {
        rebuild {
            while stack.count > 1, let top = stack.last, !predicate(top) {
                let r = stack.removeLast()
                resolveResult(for: r, with: nil)
            }
        }
    }

    public func popToFirst() {
        guard stack.count > 1 else { return }
        rebuild {
            while stack.count > 1 {
                let r = stack.removeLast()
                resolveResult(for: r, with: nil)
            }
        }
    }

    public func insert(at index: Int, route: Route) {
        rebuild {
            let clamped = max(0, min(index, stack.count))
            stack.insert(route, at: clamped)
        }
    }

    public func insert(below predicate: (Route) -> Bool, route: Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        rebuild { stack.insert(route, at: idx) }
    }

    public func insert(above predicate: (Route) -> Bool, route: Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        rebuild { stack.insert(route, at: idx + 1) }
    }

    public func remove(where predicate: (Route) -> Bool) {
        guard let idx = stack.firstIndex(where: predicate),
              stack.count > 1 else { return }
        rebuild {
            let removed = stack.remove(at: idx)
            resolveResult(for: removed, with: nil)
        }
    }

    public func remove(at index: Int) {
        guard stack.indices.contains(index), stack.count > 1 else { return }
        rebuild {
            let removed = stack.remove(at: index)
            resolveResult(for: removed, with: nil)
        }
    }

    public func replace(routes: [Route]) {
        guard !routes.isEmpty else { return }
        rebuild {
            for route in stack { resolveResult(for: route, with: nil) }
            stack = routes
        }
    }

    public func replaceTop(_ route: Route) {
        rebuild {
            if !stack.isEmpty {
                let popped = stack.removeLast()
                resolveResult(for: popped, with: nil)
            }
            stack.append(route)
        }
    }

    @discardableResult
    public func resolve(url: URL) -> Bool {
        guard let route = deepLinks.resolve(url) else { return false }
        push(route)
        return true
    }

    private func resolveResult(for route: Route, with value: Any?) {
        guard let resolver = pendingResults.removeValue(forKey: route.id) else { return }
        resolver(value)
    }
}

// MARK: - RouterBuilder

public final class RouterBuilder: ViewBuilder<RouterModel> {
    public override func build(context: ViewContext) -> any View {
        let stack = model.stack
        let topID = stack.last?.id
        let topNavItem: Observable<NavigationItem>? = topID.map { model.navItem(for: $0) }

        // Each Route is a ModelView — its RouteModel (conforming to
        // RouteHandle) is created once and preserved by the node tree.
        // The model reads position/router from context, not from the struct.
        let routeViews: [any View] = stack.map { route in
            let isTop = route.id == topID
            return Offstage(offstage: !isTop) {
                Box(.fill) { route }
            }.id(route.id)
        }

        // NavigationBar driven by the topmost route's nav item.
        let navbar: any View = Buildable { ctx in
            guard let obs = topNavItem else { return EmptyView() }
            let item = ctx.watch(obs)
            if item.hidden { return EmptyView() }
            return NavigationBar(
                leading: item.leading,
                main: item.main ?? item.title.map { Text($0) },
                trailing: item.trailing,
                bottom: item.bottom,
                alignment: item.alignment,
                padding: item.padding ?? .zero,
                hidden: item.hidden
            )
        }

        return Provided(model.handle, model) {
            Column(alignment: .topCenter) {
                navbar
                Box(.fill, children: routeViews)
            }
        }
    }
}

#endif
