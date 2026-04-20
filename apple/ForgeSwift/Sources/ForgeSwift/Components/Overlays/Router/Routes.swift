import Foundation

// MARK: - Screen

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

public enum SheetDetent: Sendable {
    case medium
    case large
    case custom(Double)
}

// MARK: - Drawer

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

public enum HorizontalEdge: Sendable {
    case leading
    case trailing
}

// MARK: - Cover

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

public enum ToastPosition: Sendable {
    case top
    case bottom
}
