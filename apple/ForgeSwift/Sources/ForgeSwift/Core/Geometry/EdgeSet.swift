/// A set of edges, represented as a bitfield.
public struct EdgeSet: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let top = EdgeSet(rawValue: 1 << 0)
    public static let bottom = EdgeSet(rawValue: 1 << 1)
    public static let leading = EdgeSet(rawValue: 1 << 2)
    public static let trailing = EdgeSet(rawValue: 1 << 3)

    public static let horizontal: EdgeSet = [.leading, .trailing]
    public static let vertical: EdgeSet = [.top, .bottom]
    public static let all: EdgeSet = [.top, .bottom, .leading, .trailing]

    public var hasTop: Bool { contains(.top) }
    public var hasBottom: Bool { contains(.bottom) }
    public var hasLeading: Bool { contains(.leading) }
    public var hasTrailing: Bool { contains(.trailing) }
}
