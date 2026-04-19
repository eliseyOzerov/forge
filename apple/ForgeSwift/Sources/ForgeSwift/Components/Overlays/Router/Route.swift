import Foundation

// MARK: - Route

/// Any view the Router can manage. Just conform and you're routable.
///
///     struct MyScreen: BuiltView, Route {
///         func build(context: ViewContext) -> any View {
///             let handle = context.route
///             Text("Hello")
///         }
///     }
@MainActor public protocol Route: View {
    var key: AnyHashable? { get }
    var opaque: Bool { get }
    var duration: Double { get }
    var cover: (@MainActor (any View, RouteHandle) -> any View)? { get }
}

public extension Route {
    var key: AnyHashable? { nil }
    var opaque: Bool { true }
    var duration: Double { 0.35 }
    var cover: (@MainActor (any View, RouteHandle) -> any View)? { nil }
}

// MARK: - RoutePhase

public enum RoutePhase: Equatable, Sendable {
    case entering
    case exiting
    case settled
    case hidden
}

// MARK: - RouteHandle

@MainActor public protocol RouteHandle: AnyObject, Listenable {
    var index: Int { get }
    var phase: RoutePhase { get }
    var progress: Double { get }
    var above: RouteHandle? { get }
    var isTop: Bool { get }
    var isBottom: Bool { get }
    var canPop: Bool { get }

    func transform(_ view: any View) -> any View
    func scrub(to progress: Double)
    func show() async
    func hide() async
    func dismiss(result: Any?, animated: Bool) async
}

public extension RouteHandle {
    func dismiss(animated: Bool = true) async {
        await dismiss(result: nil, animated: animated)
    }
}

// MARK: - RouteModel

/// Per-route state, created and owned by the router.
@MainActor
public final class RouteModel: Notifier, RouteHandle {
    let id: UUID
    let route: any Route
    weak var router: RouterModel?

    public private(set) var phase: RoutePhase = .hidden
    public private(set) var progress: Double = 0
    public private(set) var above: RouteHandle?

    private var coverSubscription: Subscription?
    private var driver: MotionDriver?
    private var progressSubscription: Subscription?

    init(id: UUID, route: any Route, router: RouterModel) {
        self.id = id
        self.route = route
        self.router = router
    }

    public var index: Int {
        router?.indexOf(routeID: id) ?? 0
    }

    public var isTop: Bool {
        router?.isTop(routeID: id) ?? false
    }

    public var isBottom: Bool { index == 0 }
    public var canPop: Bool { index > 0 }

    // MARK: - Transform

    public func transform(_ view: any View) -> any View {
        guard let coverFn = route.cover else { return view }
        return coverFn(view, self)
    }

    // MARK: - Interactive scrub

    public func scrub(to value: Double) {
        progress = min(max(value, 0), 1)
        notify()
    }

    /// Immediately set to fully shown, no animation.
    func settle() {
        progress = 1
        phase = .settled
        notify()
    }

    // MARK: - Show / Hide / Dismiss

    public func show() async {
        phase = .entering
        notify()
        await animateProgress(to: 1)
        phase = .settled
        notify()
    }

    public func hide() async {
        phase = .exiting
        notify()
        await animateProgress(to: 0)
        phase = .hidden
        notify()
    }

    public func present(router: RouterModel, animated: Bool = true) async {
        self.router = router

        if animated {
            await show()
        } else {
            progress = 1
            phase = .settled
            notify()
        }
    }

    public func dismiss(result: Any? = nil, animated: Bool = true) async {
        if animated {
            await hide()
        } else {
            progress = 0
            phase = .hidden
            notify()
        }
        router?.removeRoute(id: id, result: result)
    }

    // MARK: - Cover / Uncover

    func cover(by handle: RouteHandle) {
        above = handle
        coverSubscription = handle.listen { [weak self] in
            self?.notify()
        }
    }

    func uncover() {
        coverSubscription?.cancel()
        coverSubscription = nil
        above = nil
        notify()
    }

    // MARK: - Animation

    private func ensureDriver() -> MotionDriver {
        if let d = driver { return d }
        let d = MotionDriver(duration: Duration(route.duration))
        progressSubscription = d.observe { [weak self] p in
            guard let self else { return }
            self.progress = p
            self.notify()
        }
        driver = d
        return d
    }

    private func animateProgress(to target: Double) async {
        let d = ensureDriver()
        d.seek(to: progress)
        if target >= 1 {
            await d.forward()
        } else {
            await d.reverse()
        }
        progress = target
    }

    func dispose() {
        coverSubscription?.cancel()
        progressSubscription?.cancel()
        driver?.reset()
    }
}

// MARK: - ViewContext

public extension ViewContext {
    var router: any RouterHandle { read((any RouterHandle).self) }
    var maybeRouter: (any RouterHandle)? { tryRead((any RouterHandle).self) }
    var route: RouteHandle { read(RouteHandle.self) }
    var maybeRoute: RouteHandle? { tryRead(RouteHandle.self) }
}
