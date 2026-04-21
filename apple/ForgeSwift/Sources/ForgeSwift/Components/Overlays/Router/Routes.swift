import Foundation

// MARK: - Screen

/// Full-screen push route with swipe-back dismissal.
public struct Screen: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public var cover: (@MainActor (any View, RouteHandle) -> any View)? {
        #if canImport(UIKit)
        { view, handle in
            let t = handle.progress
            return view.effect { $0.offset(-0.3 * t, fractional: true).opacity(1 - 0.15 * t) }
        }
        #else
        nil
        #endif
    }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View {
        let route = context.watch(RouteHandle.self)

        guard !route.isBottom else { return content() }

        #if canImport(UIKit)
        let dismissValue = Binding<Double>(
            get: { 1 - route.progress },
            set: { route.scrub(to: 1 - $0) }
        )

        return Dismissible(
            value: dismissValue,
            edge: .trailing,
            threshold: DismissThreshold(distance: 0.4, velocity: 1000),
            onUpdate: { value, phase in
                if phase == .dismissed {
                    Task { await route.dismiss(animated: false) }
                }
            }
        ) { ctx, dismissProgress in
            return content()
                .effect { $0.offset(dismissProgress, fractional: true) }
        }
        #else
        return content()
        #endif
    }
}

// MARK: - Modal

/// Transparent overlay route for modal dialogs.
public struct Modal: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Sheet

/// Bottom sheet route with configurable detent stops.
public struct Sheet: BuiltView, Route {
    public let key: AnyHashable?
    public let detents: [SheetDetent]
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        detents: [SheetDetent] = [.large],
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.detents = detents
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

/// Snap height for a sheet route (medium, large, or custom fraction).
public enum SheetDetent: Sendable {
    case medium
    case large
    case custom(Double)
}

// MARK: - Drawer

/// Side drawer route sliding in from a horizontal edge.
public struct Drawer: BuiltView, Route {
    public let key: AnyHashable?
    public let edge: HorizontalEdge
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        edge: HorizontalEdge = .leading,
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.edge = edge
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

/// Leading or trailing horizontal edge.
public enum HorizontalEdge: Sendable {
    case leading
    case trailing
}

// MARK: - Cover

/// Full-screen opaque cover route without navigation chrome.
public struct Cover: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Alert

/// Centered alert dialog route.
public struct Alert: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Barrier

/// Blocking overlay route that prevents interaction with content beneath it.
public struct Barrier: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Coachmark

/// Transparent overlay route for onboarding highlights and tips.
public struct Coachmark: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - ContextMenu

/// Context menu overlay route anchored to a trigger view.
public struct ContextMenu: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Lightbox

/// Full-screen media viewer route.
public struct Lightbox: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Popover

/// Small floating overlay route positioned near an anchor point.
public struct Popover: BuiltView, Route {
    public let key: AnyHashable?
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

// MARK: - Toast

/// Temporary notification banner route that auto-dismisses after a duration.
public struct Toast: BuiltView, Route {
    public let key: AnyHashable?
    public let duration: Double
    public let position: ToastPosition
    public let content: @MainActor () -> any View
    public var opaque: Bool { false }

    public init(
        duration: Double = 3.0,
        position: ToastPosition = .bottom,
        key: AnyHashable? = nil,
        @ChildBuilder body: @escaping @MainActor () -> any View
    ) {
        self.key = key
        self.duration = duration
        self.position = position
        self.content = body
    }

    public func build(context: ViewContext) -> any View { content() }
}

/// Vertical position of a toast notification (top or bottom).
public enum ToastPosition: Sendable {
    case top
    case bottom
}
