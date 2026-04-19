import Foundation

// MARK: - RouterHandle

@MainActor public protocol RouterHandle: AnyObject {
    var routes: [any Route] { get }

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
    @discardableResult func resolve(url: URL) -> Bool
}

public extension RouterHandle {
    var top: (any Route)? { routes.last }
    var first: (any Route)? { routes.first }
    var canPop: Bool { routes.count > 1 }

    func contains(where predicate: (any Route) -> Bool) -> Bool {
        routes.contains(where: predicate)
    }

    func pop() { pop(result: nil) }
    func remove(where predicate: (any Route) -> Bool) { remove(where: predicate, result: nil, animated: true) }
    func remove(at index: Int) { remove(at: index, result: nil, animated: true) }
}

// MARK: - Router

public struct Router: ModelView {
    public let deeplinks: DeepLinkMap
    public let root: any View

    public init(
        deeplinks: DeepLinkMap = DeepLinkMap(),
        @ChildBuilder root: () -> any View
    ) {
        self.deeplinks = deeplinks
        self.root = root()
    }

    public func model(context: ViewContext) -> RouterModel {
        RouterModel(context: context, deeplinks: deeplinks)
    }

    public func builder(model: RouterModel) -> RouterBuilder {
        RouterBuilder(model: model)
    }
}

// MARK: - RouterModel

public final class RouterModel: ViewModel<Router>, RouterHandle {
    private(set) var entries: [RouteModel] = []

    private var navItems: [UUID: Observable<NavigationItem>] = [:]
    private var pendingResults: [UUID: (Any?) -> Void] = [:]
    private let deepLinks: DeepLinkMap

    public var routes: [any Route] { entries.map(\.route) }

    func indexOf(routeID: UUID) -> Int? {
        entries.firstIndex(where: { $0.id == routeID })
    }

    func isTop(routeID: UUID) -> Bool {
        entries.last?.id == routeID
    }

    func navItem(for routeID: UUID) -> Observable<NavigationItem> {
        if let existing = navItems[routeID] { return existing }
        let obs = Observable(NavigationItem())
        navItems[routeID] = obs
        return obs
    }

    func removeRoute(id: UUID, result: Any?) {
        guard let idx = entries.firstIndex(where: { $0.id == id }),
              entries.count > 1 else { return }
        rebuild {
            let removed = entries.remove(at: idx)
            removed.dispose()
            resolveResult(for: removed.id, with: result)
            updateCoverState()
        }
    }

    init(context: ViewContext, deeplinks: DeepLinkMap) {
        self.deepLinks = deeplinks
        super.init(context: context)
    }

    private func makeEntry(_ route: any Route) -> RouteModel {
        RouteModel(id: UUID(), route: route, router: self)
    }

    public override func didInit(view: Router) {
        super.didInit(view: view)
        if entries.isEmpty {
            let firstView = view.root
            let root = makeEntry(Screen { firstView })
            root.settle()
            entries = [root]
        }
    }

    public override func didUpdate(newView: Router) {
        super.didUpdate(newView: newView)
        if !entries.isEmpty {
            let firstView = newView.root
            let first = entries[0]
            entries[0] = RouteModel(id: first.id, route: Screen { firstView }, router: self)
        }
    }

    public override func didDispose() {
        for entry in entries { entry.dispose() }
        super.didDispose()
    }

    // MARK: - Cover state

    private func updateCoverState() {
        for i in 0..<entries.count {
            if i + 1 < entries.count {
                entries[i].cover(by: entries[i + 1])
            } else {
                entries[i].uncover()
            }
        }
    }

    // MARK: - RouterHandle

    public func push(_ route: any Route) {
        let entry = makeEntry(route)
        rebuild {
            entries.append(entry)
            updateCoverState()
        }
        Task { await entry.show() }
    }

    public func pushForResult<R: Sendable>(_ route: any Route) async -> R? {
        let entry = makeEntry(route)
        return await withCheckedContinuation { (continuation: CheckedContinuation<R?, Never>) in
            pendingResults[entry.id] = { any in
                continuation.resume(returning: any as? R)
            }
            rebuild {
                entries.append(entry)
                updateCoverState()
            }
            Task { await entry.show() }
        }
    }

    public func pop(result: Any? = nil) {
        guard entries.count > 1, let top = entries.last else { return }
        Task { await top.dismiss(result: result) }
    }

    public func pop(until predicate: (any Route) -> Bool) {
        rebuild {
            while entries.count > 1, let top = entries.last, !predicate(top.route) {
                let r = entries.removeLast()
                r.dispose()
                resolveResult(for: r.id, with: nil)
            }
            updateCoverState()
        }
    }

    public func popToFirst() {
        guard entries.count > 1 else { return }
        rebuild {
            while entries.count > 1 {
                let r = entries.removeLast()
                r.dispose()
                resolveResult(for: r.id, with: nil)
            }
            updateCoverState()
        }
    }

    public func insert(at index: Int, route: any Route) {
        rebuild {
            let clamped = max(0, min(index, entries.count))
            entries.insert(makeEntry(route), at: clamped)
            updateCoverState()
        }
    }

    public func insert(below predicate: (any Route) -> Bool, route: any Route) {
        guard let idx = entries.lastIndex(where: { predicate($0.route) }) else { return }
        rebuild {
            entries.insert(makeEntry(route), at: idx)
            updateCoverState()
        }
    }

    public func insert(above predicate: (any Route) -> Bool, route: any Route) {
        guard let idx = entries.lastIndex(where: { predicate($0.route) }) else { return }
        rebuild {
            entries.insert(makeEntry(route), at: idx + 1)
            updateCoverState()
        }
    }

    public func remove(where predicate: (any Route) -> Bool, result: Any? = nil, animated: Bool = true) {
        guard let idx = entries.firstIndex(where: { predicate($0.route) }),
              entries.count > 1 else { return }
        rebuild {
            let removed = entries.remove(at: idx)
            removed.dispose()
            resolveResult(for: removed.id, with: result)
            updateCoverState()
        }
    }

    public func remove(at index: Int, result: Any? = nil, animated: Bool = true) {
        guard entries.indices.contains(index), entries.count > 1 else { return }
        rebuild {
            let removed = entries.remove(at: index)
            removed.dispose()
            resolveResult(for: removed.id, with: result)
            updateCoverState()
        }
    }

    public func replace(with routes: [any Route]) {
        guard !routes.isEmpty else { return }
        rebuild {
            for entry in entries {
                entry.dispose()
                resolveResult(for: entry.id, with: nil)
            }
            entries = routes.map { makeEntry($0) }
            updateCoverState()
        }
    }

    public func replaceTop(_ route: any Route) {
        rebuild {
            if !entries.isEmpty {
                let popped = entries.removeLast()
                popped.dispose()
                resolveResult(for: popped.id, with: nil)
            }
            entries.append(makeEntry(route))
            updateCoverState()
        }
    }

    @discardableResult
    public func resolve(url: URL) -> Bool {
        guard let route = deepLinks.resolve(url) else { return false }
        push(route)
        return true
    }

    private func resolveResult(for id: UUID, with value: Any?) {
        guard let resolver = pendingResults.removeValue(forKey: id) else { return }
        resolver(value)
    }
}

// MARK: - RouterBuilder

fileprivate struct CoverTransform: BuiltView {
    let child: any View

    init(@ChildBuilder child: () -> any View) {
        self.child = child()
    }

    func build(context: ViewContext) -> any View {
        if let route = context.tryRead(RouteHandle.self),
           let above = route.above {
            return above.transform(child)
        }
        return child
    }
}

public final class RouterBuilder: ViewBuilder<RouterModel> {
    public override func build(context: ViewContext) -> any View {
        let entries = model.entries
        let topID = entries.last?.id
        let topNavItem: Observable<NavigationItem>? = topID.map { model.navItem(for: $0) }

        // Find the lowest opaque + settled route — everything below it is offstage
        var lowestVisible = 0
        for i in stride(from: entries.count - 1, through: 0, by: -1) {
            let entry = entries[i]
            if entry.route.opaque && entry.phase == .settled {
                lowestVisible = i
                break
            }
        }

        let routeViews: [any View] = entries.enumerated().map { (i, entry) in
            let navItemObs = model.navItem(for: entry.id)
            return Offstage(offstage: i < lowestVisible) {
                Provided(entry as RouteHandle, navItemObs) {
                    Box(.fill) { entry.route }
                }
            }.id(entry.id)
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

        let handle: any RouterHandle = model
        return Provided(handle, model) {
            Box(.fill, children: routeViews)
        }
    }
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

