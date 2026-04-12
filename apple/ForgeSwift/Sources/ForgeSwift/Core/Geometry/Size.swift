import CoreGraphics
import Foundation

/// A 2D extent (width x height).
public struct Size {
    public var width: Double
    public var height: Double

    public init(_ width: Double, _ height: Double) {
        self.width = width
        self.height = height
    }

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    /// Square size.
    public init(square: Double) {
        self.width = square
        self.height = square
    }

    public static let zero = Size(0, 0)

    // MARK: - Conversion

    public var cgSize: CGSize { CGSize(width: width, height: height) }
    public init(_ cgSize: CGSize) { self.width = cgSize.width; self.height = cgSize.height }

    // MARK: - Queries

    public var shortestSide: Double { min(width, height) }
    public var longestSide: Double { max(width, height) }
    public var area: Double { width * height }
    public var aspectRatio: Double { height == 0 ? 0 : width / height }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    // MARK: - Operations

    public func scaled(_ sx: Double, _ sy: Double? = nil) -> Size {
        Size(width * sx, height * (sy ?? sx))
    }

    public func lerp(to other: Size, t: Double) -> Size {
        Size(width + (other.width - width) * t, height + (other.height - height) * t)
    }

    public func toVec2() -> Vec2 { Vec2(width, height) }
}

extension Size: Equatable, Hashable, Sendable {}
