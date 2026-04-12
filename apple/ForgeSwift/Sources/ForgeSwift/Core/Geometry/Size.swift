import CoreGraphics
import Foundation

/// A 2D extent (width x height).
public struct Size {
    public var width: CGFloat
    public var height: CGFloat

    public init(_ width: CGFloat, _ height: CGFloat) {
        self.width = width
        self.height = height
    }

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    /// Square size.
    public init(square: CGFloat) {
        self.width = square
        self.height = square
    }

    public static let zero = Size(0, 0)

    // MARK: - Conversion

    public var cgSize: CGSize { CGSize(width: width, height: height) }
    public init(_ cgSize: CGSize) { self.width = cgSize.width; self.height = cgSize.height }

    // MARK: - Queries

    public var shortestSide: CGFloat { min(width, height) }
    public var longestSide: CGFloat { max(width, height) }
    public var area: CGFloat { width * height }
    public var aspectRatio: CGFloat { height == 0 ? 0 : width / height }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    // MARK: - Operations

    public func scaled(_ sx: CGFloat, _ sy: CGFloat? = nil) -> Size {
        Size(width * sx, height * (sy ?? sx))
    }

    public func lerp(to other: Size, t: CGFloat) -> Size {
        Size(width + (other.width - width) * t, height + (other.height - height) * t)
    }

    public func toVec2() -> Vec2 { Vec2(width, height) }
}

extension Size: Equatable, Hashable, Sendable {}
