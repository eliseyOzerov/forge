import Foundation

/// Sizing constraints for a view.
@Init @Copy
public struct Frame: Equatable, Sendable, Lerpable {
    public var width: Extent = .fit()
    public var height: Extent = .fit()

    public init(_ width: Extent = .fit(), _ height: Extent = .fit()) {
        self.width = width;
        self.height = height
    }

    public static func square(_ size: Double) -> Frame {
        Frame(.fix(size), .fix(size))
    }

    public func lerp(to other: Frame, t: Double) -> Frame {
        Frame(width: width.lerp(to: other.width, t: t),
              height: height.lerp(to: other.height, t: t))
    }
    
    public var flipped: Frame {
        Frame(width: height, height: width)
    }
    
    public func on(_ axis: Axis) -> Extent {
        switch axis {
        case .horizontal: return width
        case .vertical: return height
        }
    }
}

/// Inits
extension Frame {
    public static var fit: Frame { .fit() }
    
    public static func fit(_ axis: Axis? = nil, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.fit(min: min, max: max)
        switch axis {
        case nil:
            return Frame(extent, extent)
        case .horizontal:
            return Frame(extent, .fit())
        case .vertical:
            return Frame(.fit(), extent)
        }
    }

    public static func fill(_ axis: Axis? = nil, _ fill: Double = 1, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.fill(fill, min: min, max: max)
        switch axis {
        case nil:
            return Frame(extent, extent)
        case .horizontal:
            return Frame(extent, .fit())
        case .vertical:
            return Frame(.fit(), extent)
        }
    }
    
    public static func fix(_ axis: Axis? = nil, _ size: Double) -> Frame {
        let extent = Extent.fix(size)
        switch axis {
        case nil:
            return Frame(extent, extent)
        case .horizontal:
            return Frame(extent, .fit())
        case .vertical:
            return Frame(.fit(), extent)
        }
    }
    
    public static func fixed(_ width: Double, _ height: Double) -> Frame {
        Frame(.fix(width), .fix(height))
    }
    
    public static func flex(_ axis: Axis? = nil, _ flex: Double = 1, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.flex(flex, min: min, max: max)
        switch axis {
        case nil:
            return Frame(extent, extent)
        case .horizontal:
            return Frame(extent, .fit())
        case .vertical:
            return Frame(.fit(), extent)
        }
    }
}

extension Frame {
    public func fit(_ axis: Axis, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.fit(min: min, max: max)
        switch axis {
        case .horizontal:
            return self.width(extent)
        case .vertical:
            return self.height(extent)
        }
    }

    public func fill(_ axis: Axis, _ fill: Double = 1, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.fill(fill, min: min, max: max)
        switch axis {
        case .horizontal:
            return self.width(extent)
        case .vertical:
            return self.height(extent)
        }
    }
    
    public func fix(_ axis: Axis, _ size: Double) -> Frame {
        let extent = Extent.fix(size)
        switch axis {
        case .horizontal:
            return self.width(extent)
        case .vertical:
            return self.height(extent)
        }
    }
    
    public func flex(_ axis: Axis, _ flex: Double = 1, min: Double? = nil, max: Double? = nil) -> Frame {
        let extent = Extent.flex(flex, min: min, max: max)
        switch axis {
        case .horizontal:
            return self.width(extent)
        case .vertical:
            return self.height(extent)
        }
    }
}

/// How a dimension should be sized.
public enum Extent: Equatable, Sendable {
    /// Shrink to child's intrinsic size, optionally clamped.
    case fit(min: Double? = nil, max: Double? = nil)
    /// Fraction of available space. 1.0 = 100%, 0.5 = 50%.
    case fill(_ fraction: Double = 1, min: Double? = nil, max: Double? = nil)
    /// Exact size in points.
    case fix(Double)
    /// Proportion of all remaining space
    case flex(_ flex: Double = 1, min: Double? = nil, max: Double? = nil)
}

public extension Extent {
    /// The optional minimum clamp, if any.
    var min: Double? {
        switch self {
        case .fix: nil
        case .fit(let min, _): min
        case .fill(_, let min, _): min
        case .flex(_, let min, _): min
        }
    }

    /// The optional maximum clamp, if any.
    var max: Double? {
        switch self {
        case .fix: nil
        case .fit(_, let max): max
        case .fill(_, _, let max): max
        case .flex(_, _, let max): max
        }
    }
    
    var fix: Double?  { if case .fix(let v) = self { v } else { nil } }
    var fill: Double? { if case .fill(let v, _, _) = self { v } else { nil } }
    var flex: Double? { if case .flex(let v, _, _) = self { v } else { nil } }
    
    var isFit: Bool  { if case .fit  = self { true } else { false } }
    var isFix: Bool  { if case .fix  = self { true } else { false } }
    var isFill: Bool { if case .fill = self { true } else { false } }
    var isFlex: Bool { if case .flex = self { true } else { false } }
}

extension Extent: Lerpable {
    public func lerp(to other: Extent, t: Double) -> Extent {
        switch (self, other) {
        case (.fix(let a), .fix(let b)):
            return .fix(a.lerp(to: b, t: t))
        case (.fit(let aMin, let aMax), .fit(let bMin, let bMax)):
            return .fit(
                min: lerpOptional(aMin, bMin, t: t),
                max: lerpOptional(aMax, bMax, t: t)
            )
        case (.fill(let aFrac, let aMin, let aMax), .fill(let bFrac, let bMin, let bMax)):
            return .fill(
                aFrac.lerp(to: bFrac, t: t),
                min: lerpOptional(aMin, bMin, t: t),
                max: lerpOptional(aMax, bMax, t: t)
            )
        case (.flex(let aFlex, let aMin, let aMax), .flex(let bFlex, let bMin, let bMax)):
            return .flex(
                aFlex.lerp(to: bFlex, t: t),
                min: lerpOptional(aMin, bMin, t: t),
                max: lerpOptional(aMax, bMax, t: t)
            )
        default:
            return t < 0.5 ? self : other
        }
    }
}
