import Foundation

/// Sizing constraints for a view.
@Init @Copy
public struct Frame: Equatable, Sendable, Lerpable {
    public var width: Extent = .hug()
    public var height: Extent = .hug()

    public init(_ width: Extent = .hug(), _ height: Extent = .hug()) {
        self.init(width: width, height: height)
    }

    public static func fixed(_ width: Double, _ height: Double) -> Frame {
        Frame(.fix(width), .fix(height))
    }

    public static func square(_ size: Double) -> Frame {
        Frame(.fix(size), .fix(size))
    }

    public func height(_ value: Double) -> Frame {
        height(.fix(value))
    }

    public func width(_ value: Double) -> Frame {
        width(.fix(value))
    }

    public static let fill = Frame(.fill(), .fill())
    public static let hug = Frame(.hug(), .hug())

    public static let fillWidth = Frame(.fill(), .hug())
    public static let fillHeight = Frame(.hug(), .fill())

    public func lerp(to other: Frame, t: Double) -> Frame {
        Frame(width: width.lerp(to: other.width, t: t),
              height: height.lerp(to: other.height, t: t))
    }
}

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

extension Extent: Lerpable {
    public func lerp(to other: Extent, t: Double) -> Extent {
        switch (self, other) {
        case (.fix(let a), .fix(let b)):
            return .fix(a.lerp(to: b, t: t))
        case (.hug(let aMin, let aMax), .hug(let bMin, let bMax)):
            return .hug(min: lerpOptional(aMin, bMin, t: t),
                        max: lerpOptional(aMax, bMax, t: t))
        case (.fill(let aFlex, let aMin, let aMax), .fill(let bFlex, let bMin, let bMax)):
            return .fill(flex: aFlex.lerp(to: bFlex, t: t),
                         min: lerpOptional(aMin, bMin, t: t),
                         max: lerpOptional(aMax, bMax, t: t))
        default:
            return t < 0.5 ? self : other
        }
    }
}
