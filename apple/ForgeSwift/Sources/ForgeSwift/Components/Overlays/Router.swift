//
//  Router.swift
//  ForgeSwift
//
//  Route protocol + Router stack host.
//
//    - `Route`              — protocol: id + key + content. Any ModelView
//       struct can conform. The only model constraint: extend RouteModel<Self>.
//    - `RouteModel<V>`      — open base model with phase, progress, dismiss.
//    - `RouteContentBuilder` — generic ViewBuilder that renders content +
//       provides RouteHandle. Override per-type for custom presentation.
//    - `RouteEntry`         — default generic route for simple push cases.
//    - Concrete types       — Screen, Sheet, Modal, etc.
//    - `Router`             — stack host. Presentation-agnostic.
//

import Foundation

// MARK: - Route

/// Protocol for any view the Router can manage. Conform to both
/// Route and ModelView, with a model that extends RouteModel<Self>.
///
///     struct Screen: ModelView, Route {
///         let id = UUID()
///         let content: () -> any View
///         init(@ChildBuilder body: ...) { content = body }
///     }
@MainActor public protocol Route: View {
    var id: UUID { get }
    var key: AnyHashable? { get }
    var content: @MainActor () -> any View { get }
}

public extension Route {
    var key: AnyHashable? { nil }
    var content: @MainActor () -> any View { { EmptyView() } }
}

/// Default model() and builder() for routes that use RouteModel
/// and RouteContentBuilder without customization.
public extension Route where Self: ModelView,
                             Model == RouteModel<Self>,
                             Builder == RouteContentBuilder<Self> {
    func model(context: ViewContext) -> RouteModel<Self> { RouteModel(context: context) }
    func builder(model: RouteModel<Self>) -> RouteContentBuilder<Self> { RouteContentBuilder(model: model) }
}

// MARK: - RoutePhase

public enum RoutePhase: Equatable, Sendable {
    case entering
    case settled
    case covered
    case exiting
}

// MARK: - RouteHandle

@MainActor public protocol RouteHandle: AnyObject {
    var id: UUID { get }
    var index: Int { get }
    var phase: RoutePhase { get }
    var progress: Observable<Double> { get }
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

/// Base model for all routes. Extend for per-type state.
///
///     // Use as-is for simple routes:
///     func model(context:) -> RouteModel<Screen> { RouteModel(context: context) }
///
///     // Or subclass for custom state:
///     class SheetModel: RouteModel<Sheet> {
///         var currentDetent: SheetDetent = .large
///     }
open class RouteModel<V: Route>: ViewModel<V>, RouteHandle {
    public var phase: RoutePhase = .entering
    public let progress = Observable<Double>(0)

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
        router?.remove(where: { $0.id == routeID }, result: result, animated: animated)
    }
}

// MARK: - RouteContentBuilder

/// Generic builder that renders a route's content and provides
/// the RouteHandle to descendants. Subclass for custom presentation
/// (navbar wrapping, scrim, drag handle, etc.).
open class RouteContentBuilder<V: Route>: ViewBuilder<RouteModel<V>> {
    open override func build(context: ViewContext) -> any View {
        Provided(model as RouteHandle) {
            model.view.content()
        }
    }
}

// MARK: - RouteEntry

/// Default generic route. Use for simple push cases where you
/// don't need a custom type:
///
///     router.push(RouteEntry { DetailView() })
public struct RouteEntry: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

// MARK: - Concrete routes

/// Full-area navigation push. Navbar, back gesture, linear back stack.
public struct Screen: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Centered overlay sized to content. Scrim, tap-outside or X to dismiss.
public struct Modal: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Bottom partial overlay with detents and drag handle.
public struct Sheet: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let detents: [SheetDetent]
    public let content: @MainActor () -> any View

    public init(
        detents: [SheetDetent] = [.large],
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.detents = detents
        self.content = body
    }
}

public enum SheetDetent: Sendable {
    case medium
    case large
    case custom(Double)
}

/// Side panel. Scrim, drag or tap scrim to dismiss.
public struct Drawer: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let edge: HorizontalEdge
    public let content: @MainActor () -> any View

    public init(
        edge: HorizontalEdge = .leading,
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.edge = edge
        self.content = body
    }
}

public enum HorizontalEdge: Sendable {
    case leading
    case trailing
}

/// Full-screen overlay. X button or programmatic dismiss.
public struct Cover: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Centered dialog with action buttons. Blocks interaction, scrim.
public struct Alert: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Full-screen blocker (loading, auth gate). No user dismiss.
public struct Barrier: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Spotlight overlay highlighting a target element. Tap to advance.
public struct Coachmark: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Anchored menu at touch point. Tap outside to dismiss.
public struct ContextMenu: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Full-screen media viewer. Black background, tap/swipe to dismiss.
public struct Lightbox: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Anchored overlay with arrow pointing to source element.
public struct Popover: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.content = body
    }
}

/// Small notification. Auto-dismisses, non-blocking.
public struct Toast: ModelView, Route {
    public let id: UUID
    public let key: AnyHashable?
    public let duration: Double
    public let position: ToastPosition
    public let content: @MainActor () -> any View

    public init(
        duration: Double = 3.0,
        position: ToastPosition = .bottom,
        id: UUID = UUID(),
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.id = id
        self.key = key
        self.duration = duration
        self.position = position
        self.content = body
    }
}

public enum ToastPosition: Sendable {
    case top
    case bottom
}

// MARK: - Deep links

public struct DeepLink {
    public let pattern: String
    public let factory: @MainActor (URLParams) -> (any Route)?

    public init(
        _ pattern: String,
        factory: @escaping @MainActor (URLParams) -> (any Route)?
    ) {
        self.pattern = pattern
        self.factory = factory
    }
}

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

public struct DeepLinkMap {
    public let links: [DeepLink]

    public init(@DeepLinkBuilder _ build: () -> [DeepLink] = { [] }) {
        self.links = build()
    }

    @MainActor
    public func resolve(_ url: URL) -> (any Route)? {
        for link in links {
            if let params = Self.match(pattern: link.pattern, url: url),
               let route = link.factory(params) {
                return route
            }
        }
        return nil
    }

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

@MainActor public protocol RouterHandleDelegate: AnyObject {
    var stack: [any Route] { get }

    func push(_ route: any Route)
    func pushForResult<R: Sendable>(_ route: any Route) async -> R?
    func pop(result: Any?)
    func pop(until predicate: (any Route) -> Bool)
    func popToFirst()
    func insert(at index: Int, route: any Route)
    func insert(below predicate: (any Route) -> Bool, route: any Route)
    func insert(above predicate: (any Route) -> Bool, route: any Route)
    func remove(where predicate: (any Route) -> Bool, result: Any?, animated: Bool)
    func remove(at index: Int, result: Any?, animated: Bool)
    func replace(with routes: [any Route])
    func replaceTop(_ route: any Route)
    func resolve(url: URL) -> Bool
}

// MARK: - RouterHandle

@MainActor public final class RouterHandle {
    public weak var delegate: RouterHandleDelegate?

    public init() {}

    public var stack: [any Route] { delegate?.stack ?? [] }
    public var top: (any Route)? { stack.last }
    public var first: (any Route)? { stack.first }
    public var canPop: Bool { stack.count > 1 }

    public func contains(where predicate: (any Route) -> Bool) -> Bool {
        stack.contains(where: predicate)
    }

    public func push(_ route: any Route) { delegate?.push(route) }

    public func pushForResult<R: Sendable>(_ route: any Route) async -> R? {
        guard let delegate else { return nil }
        return await delegate.pushForResult(route)
    }

    public func pop(result: Any? = nil) { delegate?.pop(result: result) }
    public func pop(until predicate: (any Route) -> Bool) { delegate?.pop(until: predicate) }
    public func popToFirst() { delegate?.popToFirst() }
    public func insert(at index: Int, route: any Route) { delegate?.insert(at: index, route: route) }
    public func insert(below predicate: (any Route) -> Bool, route: any Route) { delegate?.insert(below: predicate, route: route) }
    public func insert(above predicate: (any Route) -> Bool, route: any Route) { delegate?.insert(above: predicate, route: route) }
    public func remove(where predicate: (any Route) -> Bool, result: Any? = nil, animated: Bool = true) { delegate?.remove(where: predicate, result: result, animated: animated) }
    public func remove(at index: Int, result: Any? = nil, animated: Bool = true) { delegate?.remove(at: index, result: result, animated: animated) }
    public func replace(with routes: [any Route]) { delegate?.replace(with: routes) }
    public func replaceTop(_ route: any Route) { delegate?.replaceTop(route) }

    @discardableResult
    public func resolve(url: URL) -> Bool { delegate?.resolve(url: url) ?? false }
}

public extension ViewContext {
    var router: RouterHandle { read(RouterHandle.self) }
    var maybeRouter: RouterHandle? { tryRead(RouterHandle.self) }
    var route: RouteHandle { read(RouteHandle.self) }
    var maybeRoute: RouteHandle? { tryRead(RouteHandle.self) }
}

// MARK: - UIKit-backed implementation

#if canImport(UIKit)
import UIKit

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
    public private(set) var stack: [any Route] = []

    var navItems: [UUID: Observable<NavigationItem>] = [:]
    let firstRouteID = UUID()
    private var pendingResults: [UUID: (Any?) -> Void] = [:]
    private let deepLinks: DeepLinkMap

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
            stack = [Screen(id: firstRouteID) { firstView }]
        }
        handle.delegate = self
    }

    public override func didUpdate(newView: Router) {
        super.didUpdate(newView: newView)
        if !stack.isEmpty, stack[0].id == firstRouteID {
            let firstView = newView.root
            stack[0] = Screen(id: firstRouteID) { firstView }
        }
    }

    public override func didDispose() {
        super.didDispose()
        if handle.delegate === self { handle.delegate = nil }
    }

    // MARK: - RouterHandleDelegate

    public func push(_ route: any Route) {
        rebuild { stack.append(route) }
    }

    public func pushForResult<R: Sendable>(_ route: any Route) async -> R? {
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

    public func pop(until predicate: (any Route) -> Bool) {
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

    public func insert(at index: Int, route: any Route) {
        rebuild {
            let clamped = max(0, min(index, stack.count))
            stack.insert(route, at: clamped)
        }
    }

    public func insert(below predicate: (any Route) -> Bool, route: any Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        rebuild { stack.insert(route, at: idx) }
    }

    public func insert(above predicate: (any Route) -> Bool, route: any Route) {
        guard let idx = stack.lastIndex(where: predicate) else { return }
        rebuild { stack.insert(route, at: idx + 1) }
    }

    public func remove(where predicate: (any Route) -> Bool, result: Any? = nil, animated: Bool = true) {
        guard let idx = stack.firstIndex(where: predicate),
              stack.count > 1 else { return }
        rebuild {
            let removed = stack.remove(at: idx)
            resolveResult(for: removed, with: result)
        }
    }

    public func remove(at index: Int, result: Any? = nil, animated: Bool = true) {
        guard stack.indices.contains(index), stack.count > 1 else { return }
        rebuild {
            let removed = stack.remove(at: index)
            resolveResult(for: removed, with: result)
        }
    }

    public func replace(with routes: [any Route]) {
        guard !routes.isEmpty else { return }
        rebuild {
            for route in stack { resolveResult(for: route, with: nil) }
            stack = routes
        }
    }

    public func replaceTop(_ route: any Route) {
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

    private func resolveResult(for route: any Route, with value: Any?) {
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

        let routeViews: [any View] = stack.map { route in
            let isTop = route.id == topID
            let navItemObs = model.navItem(for: route.id)
            return Offstage(offstage: !isTop) {
                Provided(navItemObs) {
                    Box(.fill) { route }
                }
            }.id(route.id)
        }

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
