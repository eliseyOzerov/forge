/// Interaction state of a UI component. OptionSet so states can combine
/// (e.g. focused + pressed).
public struct State: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let idle          = State(rawValue: 1 << 0)
    public static let pressed       = State(rawValue: 1 << 1)
    public static let disabled      = State(rawValue: 1 << 2)
    public static let focused       = State(rawValue: 1 << 3)
    public static let hovered       = State(rawValue: 1 << 4)
    public static let selected      = State(rawValue: 1 << 5)
    public static let loading       = State(rawValue: 1 << 6)
    /// Container-scroll state — set on chrome (nav/tab bars, headers,
    /// footers) when scrollable content has been scrolled underneath.
    /// Drives state-reactive decoration like Liquid-Glass intensification.
    public static let scrolledUnder = State(rawValue: 1 << 7)
}

// MARK: - HapticStyle

/// Haptic feedback intensity. Platform renderers map to native APIs.
public enum HapticStyle: Sendable {
    case light, medium, heavy, rigid, soft
    case none
}

// MARK: - Handler Types

public typealias Handler = @MainActor () -> Void
public typealias ValueHandler<T> = (T) -> Void

// MARK: - Mapper

/// Maps a value from an input type. Generic function wrapper.
public struct Mapper<T, K> {
    public let id: String?
    public let map: (T) -> K
    public init(_ map: @escaping (T) -> K) { self.id = nil; self.map = map }
    public init(_ id: String, _ map: @escaping (T) -> K) { self.id = id; self.map = map }
    public func callAsFunction(_ input: T) -> K { map(input) }
}

/// Resolves a value based on the current UI state.
public typealias StateProperty<T> = Mapper<State, T>


public extension StateProperty {
    /// Constant value regardless of state.
    static func constant(_ value: K) -> StateProperty<K> {
        StateProperty { _ in value }
    }
}
