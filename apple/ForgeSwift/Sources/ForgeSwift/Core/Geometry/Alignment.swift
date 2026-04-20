import Foundation

/// Alignment within a container. Backed by Vec2 with values -1 (start) to 1 (end).
public struct Alignment: Equatable, Hashable, Sendable, Lerpable {
    public var value: Vec2

    public var x: Double { value.x }
    public var y: Double { value.y }

    public init(_ x: Double, _ y: Double) {
        self.value = Vec2(x, y)
    }

    public init(_ value: Vec2) {
        self.value = value
    }

    // MARK: - Named Constants

    public static let left = Alignment(-1, 0)
    public static let right = Alignment(1, 0)
    public static let top = Alignment(0, -1)
    public static let bottom = Alignment(0, 1)

    public static let center = Alignment(0, 0)
    public static let topLeft = Alignment(-1, -1)
    public static let topCenter = Alignment(0, -1)
    public static let topRight = Alignment(1, -1)
    public static let centerLeft = Alignment(-1, 0)
    public static let centerRight = Alignment(1, 0)
    public static let bottomLeft = Alignment(-1, 1)
    public static let bottomCenter = Alignment(0, 1)
    public static let bottomRight = Alignment(1, 1)

    // MARK: - Queries

    public var isCenter: Bool { x == 0 && y == 0 }

    // MARK: - Interpolation

    public func lerp(to other: Alignment, t: Double) -> Alignment {
        Alignment(value.lerp(to: other.value, t: t))
    }
}
