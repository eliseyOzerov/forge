import Foundation

/// Sizing constraints for a view.
@Init @Copy
public struct Frame: Equatable, Sendable, Lerpable {
    public var width: Extent = .fit()
    public var height: Extent = .fit()

    public init(_ width: Extent = .fit(), _ height: Extent = .fit()) {
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
    public static let hug = Frame(.fit(), .fit())

    public static let fillWidth = Frame(.fill(), .fit())
    public static let fillHeight = Frame(.fit(), .fill())

    /// Resolve the inner bounds available to children given a proposed size and padding.
    ///
    /// - **fix**: inner = fixed value − padding
    /// - **fill**: inner = (fraction × proposed, clamped) − padding
    /// - **fit**: inner = proposed − padding (pass through; children determine actual size)
    public func innerBounds(proposed: Size, padding: Padding = .zero) -> Size {
        func resolve(_ extent: Extent, _ proposed: Double, _ pad: Double) -> Double {
            let resolved: Double = switch extent {
            case .fix(let v): v
            case .fill(let f, _, _): proposed * f
            case .fit: proposed
            }
            return resolved.clamped(min: extent.min, max: extent.max) - pad
        }
        return Size(
            resolve(width, proposed.width, padding.horizontal),
            resolve(height, proposed.height, padding.vertical)
        )
    }

    public func lerp(to other: Frame, t: Double) -> Frame {
        Frame(width: width.lerp(to: other.width, t: t),
              height: height.lerp(to: other.height, t: t))
    }
}

/// How a dimension should be sized.
public enum Extent: Equatable, Sendable {
    /// Shrink to child's intrinsic size, optionally clamped.
    case fit(min: Double? = nil, max: Double? = nil)
    /// Fraction of available space. 1.0 = 100%, 0.5 = 50%.
    /// When proposed size is zero, falls back to intrinsic size.
    case fill(_ fraction: Double = 1, min: Double? = nil, max: Double? = nil)
    /// Exact size in points.
    case fix(Double)
}

public extension Extent {
    /// The optional minimum clamp, if any.
    var min: Double? {
        switch self {
        case .fix: nil
        case .fit(let min, _): min
        case .fill(_, let min, _): min
        }
    }

    /// The optional maximum clamp, if any.
    var max: Double? {
        switch self {
        case .fix: nil
        case .fit(_, let max): max
        case .fill(_, _, let max): max
        }
    }
}

extension Extent: Lerpable {
    public func lerp(to other: Extent, t: Double) -> Extent {
        switch (self, other) {
        case (.fix(let a), .fix(let b)):
            return .fix(a.lerp(to: b, t: t))
        case (.fit(let aMin, let aMax), .fit(let bMin, let bMax)):
            return .fit(min: lerpOptional(aMin, bMin, t: t),
                        max: lerpOptional(aMax, bMax, t: t))
        case (.fill(let aFrac, let aMin, let aMax), .fill(let bFrac, let bMin, let bMax)):
            return .fill(aFrac.lerp(to: bFrac, t: t),
                         min: lerpOptional(aMin, bMin, t: t),
                         max: lerpOptional(aMax, bMax, t: t))
        default:
            return t < 0.5 ? self : other
        }
    }
}
