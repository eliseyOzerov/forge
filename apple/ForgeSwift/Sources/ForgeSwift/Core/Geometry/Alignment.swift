import CoreGraphics

/// Alignment within a container. Values range from -1 (start) to 1 (end) on each axis.
public struct Alignment: Equatable, Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat

    public init(_ x: CGFloat, _ y: CGFloat) {
        self.x = x
        self.y = y
    }

    // MARK: - Named Constants

    public static let topLeft = Alignment(-1, -1)
    public static let topCenter = Alignment(0, -1)
    public static let topRight = Alignment(1, -1)
    public static let centerLeft = Alignment(-1, 0)
    public static let center = Alignment(0, 0)
    public static let centerRight = Alignment(1, 0)
    public static let bottomLeft = Alignment(-1, 1)
    public static let bottomCenter = Alignment(0, 1)
    public static let bottomRight = Alignment(1, 1)

    // MARK: - Queries

    public var isTop: Bool { y == -1 }
    public var isBottom: Bool { y == 1 }
    public var isLeft: Bool { x == -1 }
    public var isRight: Bool { x == 1 }
    public var isCenter: Bool { x == 0 && y == 0 }

    // MARK: - Interpolation

    public func lerp(to other: Alignment, t: CGFloat) -> Alignment {
        Alignment(x + (other.x - x) * t, y + (other.y - y) * t)
    }
}
