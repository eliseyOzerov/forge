/// How a container handles content larger than its bounds.
public enum Overflow {
    case clip
    case visible
    case scroll(Axis? = nil, ScrollState? = nil)
}

/// Observable scroll state for programmatic control.
@MainActor
public final class ScrollState {
    public var offset: Vec2 = .zero
    public var contentSize: Size = .zero
    public var viewportSize: Size = .zero

    public var isAtTop: Bool { offset.y <= 0 }
    public var isAtBottom: Bool { offset.y >= contentSize.height - viewportSize.height }
    public var isAtLeading: Bool { offset.x <= 0 }
    public var isAtTrailing: Bool { offset.x >= contentSize.width - viewportSize.width }

    public var onScroll: ((Vec2) -> Void)?

    public init() {}

    // Commands — set by BoxView's scroll delegate
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
