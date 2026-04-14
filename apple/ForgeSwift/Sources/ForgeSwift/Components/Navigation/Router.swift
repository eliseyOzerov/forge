//
//  Router.swift
//  ForgeSwift
//
//  A Router wraps a UINavigationController and drives its stack from
//  two layers:
//
//    Router { … }                      declarative closure, seeds & owns
//                                       baseline routes
//    ctx.router.push(MyRoute())         imperative handle, read via
//                                       BuildContext from any descendant
//
//  Descendants inside any route read `ctx.router` to drive navigation
//  — no prop drilling, no per-screen router object. Each hosted route
//  tree is wrapped in `Provided(handle)` so the handle is available
//  throughout every route's subtree.
//
//  Identity & reconciliation: routes are Hashable; the router diffs
//  its resolved stack against the live UINavigationController stack,
//  matching by route id. Existing view controllers whose routes
//  survive are reused; new routes get fresh ForgeHostingControllers.
//

#if canImport(UIKit)
import UIKit

// MARK: - Router

public struct Router: ModelView {
    public let routes: @MainActor () -> [AnyRoute]

    public init(@RouteBuilder routes: @escaping @MainActor () -> [AnyRoute]) {
        self.routes = routes
    }

    public func makeModel(context: BuildContext) -> RouterModel { RouterModel() }
    public func makeBuilder() -> RouterBuilder { RouterBuilder() }
}

// MARK: - Model

public final class RouterModel: ViewModel<Router> {
    public let handle = RouterHandle()

    public override func didInit() {
        handle.setDeclarative(view.routes())
    }

    public override func didUpdate(from oldView: Router) {
        handle.setDeclarative(view.routes())
    }
}

// MARK: - Builder

public final class RouterBuilder: ViewBuilder<RouterModel> {
    public override func build(context: BuildContext) -> any View {
        RouterHost(handle: model.handle)
    }
}

// MARK: - BuildContext sugar

public extension BuildContext {
    /// The nearest ancestor Router's handle. Fatal if no Router is
    /// above this point in the tree — wrap your subtree in a Router
    /// or use `maybeRouter` for optional access.
    var router: RouterHandle {
        read(RouterHandle.self)
    }

    /// Optional access to the ancestor Router's handle.
    var maybeRouter: RouterHandle? {
        maybeWatch(RouterHandle.self)
    }
}

// MARK: - Host

/// Leaf view that owns the UINavigationController and diffs the
/// handle's resolved stack into it.
struct RouterHost: LeafView {
    let handle: RouterHandle

    func makeRenderer() -> Renderer {
        RouterHostRenderer(handle: handle)
    }
}

final class RouterHostRenderer: Renderer {
    let handle: RouterHandle

    init(handle: RouterHandle) {
        self.handle = handle
    }

    func mount() -> PlatformView {
        let v = RouterHostView()
        v.attach(handle: handle)
        return v
    }

    func update(_ platformView: PlatformView) {
        guard let v = platformView as? RouterHostView else { return }
        v.attach(handle: handle)
    }
}

final class RouterHostView: UIView {
    private let nav = UINavigationController()
    private weak var handle: RouterHandle?

    /// Route ids currently represented in nav.viewControllers, in
    /// the same order as nav.viewControllers.
    private var hostedIds: [AnyHashable] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize { size }

    func attach(handle: RouterHandle) {
        self.handle = handle
        handle.onChange = { [weak self] in self?.reconcile() }
        reconcile()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, nav.parent == nil else { return }
        guard let parentVC = findParentViewController() else { return }
        parentVC.addChild(nav)
        addSubview(nav.view)
        nav.view.frame = bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        nav.didMove(toParent: parentVC)
        // Apply the current stack now that the nav is mounted.
        reconcile()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        nav.view.frame = bounds
    }

    // MARK: Reconcile

    private func reconcile() {
        guard let handle else { return }
        let target = handle.resolvedStack
        let targetIds = target.map { $0.id }

        // Fast path: nothing to do.
        if targetIds == hostedIds { return }

        // Map existing viewControllers by route id so we can reuse
        // them when the same route survives.
        var existingById: [AnyHashable: UIViewController] = [:]
        for (idx, id) in hostedIds.enumerated() where idx < nav.viewControllers.count {
            existingById[id] = nav.viewControllers[idx]
        }

        let newVCs: [UIViewController] = target.map { route in
            if let existing = existingById[route.id] {
                return existing
            }
            return ForgeHostingController(route: route, handle: handle)
        }

        let shouldAnimate = window != nil && !hostedIds.isEmpty
        nav.setViewControllers(newVCs, animated: shouldAnimate)
        hostedIds = targetIds
    }

    // MARK: Parent VC lookup

    private func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = self.next
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

// MARK: - ForgeHostingController

/// UIViewController that hosts a Forge view via its own Resolver,
/// with the router handle wired into the subtree via Provided.
public final class ForgeHostingController: UIViewController {
    private let route: AnyRoute
    private weak var handle: RouterHandle?
    private let resolver = Resolver()

    init(route: AnyRoute, handle: RouterHandle) {
        self.route = route
        self.handle = handle
        super.init(nibName: nil, bundle: nil)
        self.title = route.title
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let container = UIView()
        container.backgroundColor = .systemBackground
        self.view = container

        guard let handle else { return }
        let wrapped = Provided(handle) { [route] in
            route.body()
        }
        let platform = resolver.mount(wrapped)
        platform.frame = container.bounds
        platform.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(platform)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(route.navigationBarHidden, animated: animated)
    }
}

#endif
