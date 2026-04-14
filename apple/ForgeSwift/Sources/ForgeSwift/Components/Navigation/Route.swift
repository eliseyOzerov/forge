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

// MARK: - Route

@MainActor public protocol Route: Hashable {
    /// The view rendered when this route is active.
    func body() -> any View

    /// Optional title shown in the navigation bar.
    var title: String? { get }

    /// Whether the nav bar is hidden for this route.
    var navigationBarHidden: Bool { get }
}

public extension Route {
    var title: String? { nil }
    var navigationBarHidden: Bool { false }
}

// MARK: - AnyRoute

/// Type-erased Route. Used for internal storage where the concrete
/// type is irrelevant; identity is preserved via AnyHashable.
public struct AnyRoute: Hashable {
    public let id: AnyHashable
    public let title: String?
    public let navigationBarHidden: Bool
    public let body: @MainActor () -> any View

    @MainActor public init<R: Route>(_ route: R) {
        self.id = AnyHashable(route)
        self.title = route.title
        self.navigationBarHidden = route.navigationBarHidden
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
