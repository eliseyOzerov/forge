import Foundation

/// How a dimension should be sized.
public enum Extent: Sendable {
    /// Shrink to child's intrinsic size, optionally clamped.
    case hug(min: Double? = nil, max: Double? = nil)
    /// Expand to fill available space. Flex determines ratio when
    /// siblings compete. Min/max constrain the result.
    case fill(flex: Double = 1, min: Double? = nil, max: Double? = nil)
    /// Exact size in points.
    case fix(Double)
}

/// Sizing constraints for a view.
public struct Frame: Sendable {
    public var width: Extent
    public var height: Extent

    public init(width: Extent = .hug(), height: Extent = .hug()) {
        self.width = width
        self.height = height
    }

    public static func fixed(_ width: Double, _ height: Double) -> Frame {
        Frame(width: .fix(width), height: .fix(height))
    }

    public static func square(_ size: Double) -> Frame {
        Frame(width: .fix(size), height: .fix(size))
    }

    public static let fill = Frame(width: .fill(), height: .fill())
    public static let hug = Frame(width: .hug(), height: .hug())
    public static let fillWidth = Frame(width: .fill(), height: .hug())
    public static let fillHeight = Frame(width: .hug(), height: .fill())
}
