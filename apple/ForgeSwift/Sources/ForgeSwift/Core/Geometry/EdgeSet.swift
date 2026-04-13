/// An edge of a rectangle.
public enum Edge: Int8, CaseIterable, Sendable {
    case top, bottom, leading, trailing

    /// A set of edges, represented as a bitfield.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let top = Set(rawValue: 1 << 0)
        public static let bottom = Set(rawValue: 1 << 1)
        public static let leading = Set(rawValue: 1 << 2)
        public static let trailing = Set(rawValue: 1 << 3)

        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
        public static let all: Set = [.top, .bottom, .leading, .trailing]

        public var hasTop: Bool { contains(.top) }
        public var hasBottom: Bool { contains(.bottom) }
        public var hasLeading: Bool { contains(.leading) }
        public var hasTrailing: Bool { contains(.trailing) }
    }
}
