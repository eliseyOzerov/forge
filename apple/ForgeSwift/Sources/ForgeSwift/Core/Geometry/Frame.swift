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
    /// Fraction of available space. 1.0 = 100%, 0.5 = 50%.
    /// When proposed size is zero, falls back to intrinsic size.
    case fill(_ fraction: Double = 1, min: Double? = nil, max: Double? = nil)
    /// Exact size in points.
    case fix(Double)
    /// Weight-based distribution in sequential layouts (Flex).
    /// Ignored by independent layouts (Box). Weight determines ratio
    /// of remaining space: flex(1) vs flex(2) = 1:2 split.
    case flex(_ weight: Int = 1, min: Double? = nil, max: Double? = nil)
}

public extension Extent {
    /// The optional minimum clamp, if any.
    var min: Double? {
        switch self {
        case .fix: nil
        case .hug(let min, _): min
        case .fill(_, let min, _): min
        case .flex(_, let min, _): min
        }
    }

    /// The optional maximum clamp, if any.
    var max: Double? {
        switch self {
        case .fix: nil
        case .hug(_, let max): max
        case .fill(_, _, let max): max
        case .flex(_, _, let max): max
        }
    }
}

extension Extent: Lerpable {
    public func lerp(to other: Extent, t: Double) -> Extent {
        switch (self, other) {
        case (.fix(let a), .fix(let b)):
            return .fix(a.lerp(to: b, t: t))
        case (.hug(let aMin, let aMax), .hug(let bMin, let bMax)):
            return .hug(min: lerpOptional(aMin, bMin, t: t),
                        max: lerpOptional(aMax, bMax, t: t))
        case (.fill(let aFrac, let aMin, let aMax), .fill(let bFrac, let bMin, let bMax)):
            return .fill(aFrac.lerp(to: bFrac, t: t),
                         min: lerpOptional(aMin, bMin, t: t),
                         max: lerpOptional(aMax, bMax, t: t))
        case (.flex(let aW, let aMin, let aMax), .flex(let bW, let bMin, let bMax)):
            return .flex(Int(Double(aW).lerp(to: Double(bW), t: t)),
                         min: lerpOptional(aMin, bMin, t: t),
                         max: lerpOptional(aMax, bMax, t: t))
        default:
            return t < 0.5 ? self : other
        }
    }
}
