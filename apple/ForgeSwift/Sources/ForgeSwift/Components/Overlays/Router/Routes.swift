import Foundation

// MARK: - Screen

public struct Screen: BuiltView, Route {
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
