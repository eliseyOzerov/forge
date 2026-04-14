//
//  Route.swift
//  ForgeSwift
//
//  A Route is a Hashable value describing one "screen" in a Router's
//  stack. Routes supply their own body and metadata. Identity comes
//  from Hashable conformance — the reconciler matches routes across
//  rebuilds by id, so the UINavigationController can preserve view
//  controller state when a route survives from one render to the next.
//

import Foundation

// MARK: - NavigationItem

/// Per-route configuration for the native iOS navigation bar. Fields
/// map to UINavigationItem; the host (ForgeHostingController) applies
/// them when the route becomes active.
///
/// Mirrors the shape of Wave's AppBar widget so Wave screens can port
/// with minimal adaptation, but backed by UINavigationItem on iOS
/// rather than a custom bar view.
public struct NavigationItem {
    /// Title string. If `main` is also set, `main` wins.
    public var title: String?

    /// Custom title view. Rendered as a UIView via Resolver and
    /// installed as `navigationItem.titleView`.
    public var main: (any View)?

    /// Leading bar item. If nil and `hideImplicitBackButton` is false,
    /// the system back button is shown.
    public var leading: (any View)?

    /// Trailing bar item.
    public var trailing: (any View)?

    /// Widget displayed below the main bar content (search, tabs,
    /// segmented controls). Wired via a custom accessory view; v1
    /// places it in the nav bar's scroll-edge accessory area if
    /// available, otherwise a bottom bar within the hosted view.
    public var bottom: (any View)?

    /// Bar background. State-aware (`.scrolledUnder` / `.idle`) —
    /// mapped to UINavigationBarAppearance.standardAppearance vs
    /// scrollEdgeAppearance on iOS.
    public var background: StateProperty<BoxStyle>?

    /// Whether the navigation bar is hidden for this route.
    public var hidden: Bool

    /// Suppresses the system back button when `leading` is nil.
    public var hideImplicitBackButton: Bool

    /// Override the back action. If set, replaces the system back
    /// button with a custom one that calls this closure on tap.
    /// Typical use: guard against data loss before popping.
    public var onBack: (() -> Void)?

    /// Alignment for the main/title slot across the full bar width.
    /// Mirrors AppBar.mainAlignment — if centered content overflows
    /// leading/trailing, the layout falls back to centering in the
    /// remaining free space.
    public var mainAlignment: HorizontalAlignment

    /// Padding around the bar's content.
    public var contentPadding: Padding?

    public init(
        title: String? = nil,
        main: (any View)? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        background: StateProperty<BoxStyle>? = nil,
        hidden: Bool = false,
        hideImplicitBackButton: Bool = false,
        onBack: (() -> Void)? = nil,
        mainAlignment: HorizontalAlignment = .center,
        contentPadding: Padding? = nil
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
        self.mainAlignment = mainAlignment
        self.contentPadding = contentPadding
    }
}

public enum HorizontalAlignment: Sendable {
    case leading, center, trailing
}

// MARK: - RoutePresentation

/// How a route is presented on screen. Screen routes go into the
/// UINavigationController stack; all others are overlays presented
/// atop the current stack via UIKit's presentation APIs.
///
/// v1 constraint: at most one non-screen route may follow the nav
/// stack; nested / stacked overlays are future work.
public enum RoutePresentation: @unchecked Sendable {
    case screen
    case sheet(SheetStyle = SheetStyle())
    case cover(CoverStyle = CoverStyle())
    case modal(ModalStyle = ModalStyle())
    case alert(AlertStyle = AlertStyle())
    case drawer(DrawerStyle = DrawerStyle())
    case popover(PopoverStyle)
    case toast(ToastStyle = ToastStyle())
    case lightbox(LightboxStyle = LightboxStyle())
    case coachMark(CoachMarkStyle)
    case contextMenu(ContextMenuStyle)
}

public enum SheetDetent: Sendable, Hashable {
    case medium
    case large
    /// Fractional height of the screen, 0.0 to 1.0.
    case fraction(Double)
    /// Absolute height in points.
    case height(Double)
}

// MARK: - Route

@MainActor public protocol Route: Hashable {
    /// The view rendered when this route is active.
    func body() -> any View

    /// Per-route navigation bar configuration.
    var navigationItem: NavigationItem { get }

    /// How this route is presented. Defaults to `.screen`.
    var presentation: RoutePresentation { get }
}

public extension Route {
    var navigationItem: NavigationItem { NavigationItem() }
    var presentation: RoutePresentation { .screen }
}

// MARK: - AnyRoute

/// Type-erased Route. Used for internal storage where the concrete
/// type is irrelevant; identity is preserved via AnyHashable.
public struct AnyRoute: Hashable {
    public let id: AnyHashable
    public let navigationItem: NavigationItem
    public let presentation: RoutePresentation
    public let body: @MainActor () -> any View

    @MainActor public init<R: Route>(_ route: R) {
        self.id = AnyHashable(route)
        self.navigationItem = route.navigationItem
        self.presentation = route.presentation
        self.body = { route.body() }
    }

    public static func == (lhs: AnyRoute, rhs: AnyRoute) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RouteBuilder

/// Result builder that collects Route-conforming expressions into
/// an ordered [AnyRoute]. Used by Router's declarative closure.
///
///     Router {
///         RootRoute()
///         if signedIn { HomeRoute() }
///         for id in pinned { ActivityRoute(id: id) }
///     }
@MainActor @resultBuilder
public struct RouteBuilder {
    public static func buildExpression<R: Route>(_ route: R) -> [AnyRoute] {
        [AnyRoute(route)]
    }

    public static func buildExpression(_ route: AnyRoute) -> [AnyRoute] {
        [route]
    }

    public static func buildExpression(_ routes: [AnyRoute]) -> [AnyRoute] {
        routes
    }

    public static func buildBlock(_ components: [AnyRoute]...) -> [AnyRoute] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AnyRoute]?) -> [AnyRoute] {
        component ?? []
    }

    public static func buildEither(first component: [AnyRoute]) -> [AnyRoute] {
        component
    }

    public static func buildEither(second component: [AnyRoute]) -> [AnyRoute] {
        component
    }

    public static func buildArray(_ components: [[AnyRoute]]) -> [AnyRoute] {
        components.flatMap { $0 }
    }
}
