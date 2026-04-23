/// How a container handles content larger than its bounds.
public enum Overflow: Equatable {
    case clip
    case visible
}

/// Configuration for scroll overflow behavior.
@Init @Copy
public struct ScrollConfig: Equatable {
    public var axis: Axis?
    @Snap public var state: ScrollState?
    public var showsIndicators: Bool = true
    public var bounces: Bool = true
    public var paging: Bool = false
    public var safeArea: Bool = false
}

/// Observable scroll state for programmatic control.
@MainActor
public final class ScrollState: Equatable {
    nonisolated public static func ==(lhs: ScrollState, rhs: ScrollState) -> Bool { lhs === rhs }

    public var offset: Vec2 = .zero
    public var contentSize: Size = .zero
    public var viewportSize: Size = .zero

    public var isAtTop: Bool { offset.y <= 0 }
    public var isAtBottom: Bool { offset.y >= contentSize.height - viewportSize.height }
    public var isAtLeading: Bool { offset.x <= 0 }
    public var isAtTrailing: Bool { offset.x >= contentSize.width - viewportSize.width }

    public var onScroll: ((Vec2) -> Void)?

    public init() {}

    var scrollCommand: ((Vec2, Bool) -> Void)?

    public func scrollTo(_ offset: Vec2, animated: Bool = true) {
        scrollCommand?(offset, animated)
    }

    public func scrollToTop(animated: Bool = true) {
        scrollTo(Vec2(offset.x, 0), animated: animated)
    }

    public func scrollToBottom(animated: Bool = true) {
        scrollTo(Vec2(offset.x, contentSize.height - viewportSize.height), animated: animated)
    }
}
