import Foundation

/// How a dimension should be sized.
public enum Extent: Equatable, Sendable {
    /// Shrink to child's intrinsic size, optionally clamped.
    case hug(min: Double? = nil, max: Double? = nil)
    /// Expand to fill available space. Flex determines ratio when
    /// siblings compete. Min/max constrain the result.
    case fill(flex: Double = 1, min: Double? = nil, max: Double? = nil)
    /// Exact size in points.
    case fix(Double)
}

/// Sizing constraints for a view.
public struct Frame: Equatable, Sendable {
    public var width: Extent
    public var height: Extent

    public init(_ width: Extent = .hug(), _ height: Extent = .hug()) {
        self.width = width
        self.height = height
    }

    public static func fixed(_ width: Double, _ height: Double) -> Frame {
        Frame(.fix(width), .fix(height))
    }

    public static func square(_ size: Double) -> Frame {
        Frame(.fix(size), .fix(size))
    }
    
    public static func height(_ extent: Extent) -> Frame {
        Frame(.hug(), extent)
    }
    
    public static func width(_ extent: Extent) -> Frame {
        Frame(extent, .hug())
    }
    
    public func height(_ extent: Extent) -> Frame {
        Frame(self.width, extent)
    }
    
    public func height(_ value: Double) -> Frame {
        Frame(self.width, .fix(value))
    }
    
    public func width(_ extent: Extent) -> Frame {
        Frame(extent, self.height)
    }
    
    public func width(_ value: Double) -> Frame {
        Frame(.fix(value), self.height)
    }

    public static let fill = Frame(.fill(), .fill())
    public static let hug = Frame(.hug(), .hug())
    
    public static let fillWidth = Frame(.fill(), .hug())
    public static let fillHeight = Frame(.hug(), .fill())

}
