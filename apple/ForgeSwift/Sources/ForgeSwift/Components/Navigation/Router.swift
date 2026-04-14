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

    /// Route ids currently in nav.viewControllers, same order.
    private var hostedScreenIds: [AnyHashable] = []

    /// Id of the sheet currently presented atop the nav, or nil if
    /// none. Tracked separately from the nav stack.
    private var hostedSheetId: AnyHashable?

    /// The VC we last presented as a sheet (retained weakly by the
    /// presenting stack; we just need its id for diff checks).
    private weak var hostedSheetVC: UIViewController?

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

        // Partition: leading screens go to the nav stack; the first
        // non-screen route ends the screen run and becomes the
        // presented overlay. Routes after that are ignored in v1
        // (nested / stacked overlays are future work).
        var screens: [AnyRoute] = []
        var overlay: AnyRoute? = nil
        for route in target {
            switch route.presentation {
            case .screen:
                if overlay == nil { screens.append(route) }
            default:
                if overlay == nil { overlay = route }
            }
        }

        reconcileScreens(screens, handle: handle)
        reconcileOverlay(overlay, handle: handle)
    }

    private func reconcileScreens(_ routes: [AnyRoute], handle: RouterHandle) {
        let targetIds = routes.map { $0.id }
        if targetIds == hostedScreenIds { return }

        var existingById: [AnyHashable: UIViewController] = [:]
        for (idx, id) in hostedScreenIds.enumerated() where idx < nav.viewControllers.count {
            existingById[id] = nav.viewControllers[idx]
        }

        let newVCs: [UIViewController] = routes.map { route in
            if let existing = existingById[route.id] {
                return existing
            }
            return ForgeHostingController(route: route, handle: handle)
        }

        let shouldAnimate = window != nil && !hostedScreenIds.isEmpty
        nav.setViewControllers(newVCs, animated: shouldAnimate)
        hostedScreenIds = targetIds
    }

    private func reconcileOverlay(_ route: AnyRoute?, handle: RouterHandle) {
        // Same overlay as before — nothing to do.
        if route?.id == hostedSheetId { return }

        // Dismiss current if different or gone, then optionally show
        // the new one in the completion.
        if hostedSheetId != nil, let presented = nav.presentedViewController,
           presented === hostedSheetVC {
            presented.dismiss(animated: true) { [weak self] in
                self?.presentOverlayIfNeeded(route, handle: handle)
            }
            hostedSheetId = nil
            hostedSheetVC = nil
            // Toasts auto-dismiss, so nothing to do if target is also a toast.
            return
        }

        presentOverlayIfNeeded(route, handle: handle)
    }

    private func presentOverlayIfNeeded(_ route: AnyRoute?, handle: RouterHandle) {
        guard let route else { return }

        switch route.presentation {
        case .screen:
            return  // not our concern
        case .sheet(let style):
            presentSheet(route, style: style, handle: handle)
        case .cover(let style):
            presentOpaque(route, handle: handle, style: .fullScreen, duration: style.transitionDuration)
        case .lightbox(let style):
            presentLightbox(route, style: style, handle: handle)
        case .toast(let style):
            presentToast(route, style: style, handle: handle)
        case .modal, .alert, .drawer, .popover, .coachMark, .contextMenu:
            // v2 — bridge stub.
            #if DEBUG
            print("[Forge] Router: presentation \(route.presentation) not yet bridged; skipping.")
            #endif
        }
    }

    private func presentSheet(_ route: AnyRoute, style: SheetStyle, handle: RouterHandle) {
        let vc = ForgeHostingController(route: route, handle: handle)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = style.detents.map { Self.uiDetent(from: $0) }
            sheet.prefersGrabberVisible = style.grabberVisible
            if let cornerRadius = style.cornerRadius {
                sheet.preferredCornerRadius = cornerRadius
            }
        }
        vc.isModalInPresentation = !style.isDismissable

        hostedSheetId = route.id
        hostedSheetVC = vc

        let presenter: UIViewController = nav.topViewController ?? nav
        presenter.present(vc, animated: window != nil)
    }

    private func presentOpaque(
        _ route: AnyRoute,
        handle: RouterHandle,
        style: UIModalPresentationStyle,
        duration: TimeInterval
    ) {
        let vc = ForgeHostingController(route: route, handle: handle)
        vc.modalPresentationStyle = style
        vc.modalTransitionStyle = .coverVertical

        hostedSheetId = route.id
        hostedSheetVC = vc

        let presenter: UIViewController = nav.topViewController ?? nav
        presenter.present(vc, animated: window != nil)
    }

    private func presentLightbox(_ route: AnyRoute, style: LightboxStyle, handle: RouterHandle) {
        let vc = ForgeHostingController(route: route, handle: handle)
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.view.backgroundColor = style.background.platformColor

        hostedSheetId = route.id
        hostedSheetVC = vc

        let presenter: UIViewController = nav.topViewController ?? nav
        presenter.present(vc, animated: window != nil)
    }

    private func presentToast(_ route: AnyRoute, style: ToastStyle, handle: RouterHandle) {
        guard let window = self.window else { return }

        // Toast is a floating UIView on the key window. It does not
        // occupy the overlay slot in the nav presentation chain; it
        // lives alongside whatever else is on screen.
        let toastView = ToastHostView(route: route, style: style, handle: handle) { [weak self] in
            // Auto-dismiss: remove from window and from the router.
            self?.handle?.remove(id: route.id)
        }
        window.addSubview(toastView)
        toastView.present(in: window)

        hostedSheetId = route.id
        // Note: we don't store hostedSheetVC here — toast isn't a VC.
    }

    private static func uiDetent(from detent: SheetDetent) -> UISheetPresentationController.Detent {
        switch detent {
        case .medium: return .medium()
        case .large: return .large()
        case .fraction(let f):
            if #available(iOS 16.0, *) {
                return .custom { ctx in ctx.maximumDetentValue * f }
            }
            return f < 0.75 ? .medium() : .large()
        case .height(let h):
            if #available(iOS 16.0, *) {
                return .custom { _ in h }
            }
            return .large()
        }
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

// MARK: - ToastHostView

/// Floating, self-dismissing notification view mounted on the key
/// window. Slides in from the configured edge, waits for the display
/// duration, then slides out and calls `onDismiss`.
final class ToastHostView: UIView {
    private let route: AnyRoute
    private let style: ToastStyle
    private weak var handle: RouterHandle?
    private let onDismiss: () -> Void
    private let contentResolver = Resolver()
    private var dismissTimer: Timer?

    init(
        route: AnyRoute,
        style: ToastStyle,
        handle: RouterHandle,
        onDismiss: @escaping () -> Void
    ) {
        self.route = route
        self.style = style
        self.handle = handle
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(in window: UIWindow) {
        let wrapped: any View
        if let handle {
            wrapped = Provided(handle) { [route] in route.body() }
        } else {
            wrapped = route.body()
        }
        let content = contentResolver.mount(wrapped)
        addSubview(content)

        // Size content to its intrinsic width, sit at the configured edge.
        let maxSize = CGSize(
            width: window.bounds.width - (style.padding.leading + style.padding.trailing),
            height: window.bounds.height
        )
        let fit = content.sizeThatFits(maxSize)
        let height = max(fit.height, 1)
        let width = min(fit.width, maxSize.width)

        content.frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.frame = CGRect(x: 0, y: 0, width: width, height: height)

        // Positioning
        let safe = window.safeAreaInsets
        let x = (window.bounds.width - width) / 2
        let finalY: CGFloat
        let startY: CGFloat
        switch style.position {
        case .top:
            finalY = safe.top + style.padding.top
            startY = -(height + safe.top)
        case .bottom, .leading, .trailing:
            finalY = window.bounds.height - safe.bottom - height - style.padding.bottom
            startY = window.bounds.height
        }

        self.frame.origin = CGPoint(x: x, y: startY)
        UIView.animate(withDuration: style.transitionDuration) { [self] in
            self.frame.origin.y = finalY
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: style.displayDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    private func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        UIView.animate(withDuration: style.transitionDuration, animations: { [self] in
            alpha = 0
        }, completion: { [weak self] _ in
            self?.removeFromSuperview()
            self?.onDismiss()
        })
    }
}

// MARK: - ForgeHostingController

/// UIViewController that hosts a Forge view via its own Resolver,
/// with the router handle wired into the subtree via Provided. Also
/// configures the native UINavigationItem from the route's
/// NavigationItem — title, custom title view, leading/trailing bar
/// buttons, hidden state, custom back action.
public final class ForgeHostingController: UIViewController {
    private let route: AnyRoute
    private weak var handle: RouterHandle?
    private let contentResolver = Resolver()

    /// Separate resolvers for each bar slot — each is its own subtree,
    /// retained here for the lifetime of the hosted controller so its
    /// Node graph isn't collected.
    private var mainResolver: Resolver?
    private var leadingResolver: Resolver?
    private var trailingResolver: Resolver?

    private var onBackHandler: (() -> Void)?

    init(route: AnyRoute, handle: RouterHandle) {
        self.route = route
        self.handle = handle
        super.init(nibName: nil, bundle: nil)
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
        let platform = contentResolver.mount(wrapped)
        platform.frame = container.bounds
        platform.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(platform)

        configureNavigationItem()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(route.navigationItem.hidden, animated: animated)
    }

    // MARK: Nav item configuration

    private func configureNavigationItem() {
        let item = route.navigationItem
        let nav = self.navigationItem

        // Title + optional custom title view. Keep the string title
        // set so the back button on a pushed child can display it.
        self.title = item.title
        if let main = item.main {
            let resolver = Resolver()
            mainResolver = resolver
            nav.titleView = resolver.mount(wrap(main))
        } else {
            nav.titleView = nil
        }

        // Leading: custom view > onBack intercept > system back.
        if let leading = item.leading {
            let resolver = Resolver()
            leadingResolver = resolver
            let v = resolver.mount(wrap(leading))
            nav.leftBarButtonItem = UIBarButtonItem(customView: v)
            nav.hidesBackButton = true
        } else if let onBack = item.onBack {
            onBackHandler = onBack
            let button = UIBarButtonItem(
                image: UIImage(systemName: "chevron.backward"),
                style: .plain,
                target: self,
                action: #selector(customBackTapped)
            )
            nav.leftBarButtonItem = button
            nav.hidesBackButton = true
        } else {
            nav.leftBarButtonItem = nil
            nav.hidesBackButton = item.hideImplicitBackButton
        }

        // Trailing.
        if let trailing = item.trailing {
            let resolver = Resolver()
            trailingResolver = resolver
            let v = resolver.mount(wrap(trailing))
            nav.rightBarButtonItem = UIBarButtonItem(customView: v)
        } else {
            nav.rightBarButtonItem = nil
        }
    }

    @objc private func customBackTapped() {
        onBackHandler?()
    }

    /// Wrap a bar-slot view with Provided(handle) so a button living
    /// in the nav bar can still call ctx.router.push/pop/etc.
    private func wrap(_ view: any View) -> any View {
        guard let handle else { return view }
        return Provided(handle) { view }
    }
}

#endif
