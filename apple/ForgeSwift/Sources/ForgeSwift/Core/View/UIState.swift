/// Interaction state of a UI component. OptionSet so states can combine
/// (e.g. focused + pressed).
public struct UIState: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let idle     = UIState(rawValue: 1 << 0)
    public static let pressed  = UIState(rawValue: 1 << 1)
    public static let disabled = UIState(rawValue: 1 << 2)
    public static let focused  = UIState(rawValue: 1 << 3)
    public static let hovered  = UIState(rawValue: 1 << 4)
    public static let selected = UIState(rawValue: 1 << 5)
    public static let loading  = UIState(rawValue: 1 << 6)
}

// MARK: - HapticStyle

/// Haptic feedback intensity. Platform renderers map to native APIs.
public enum HapticStyle: Sendable {
    case light, medium, heavy, rigid, soft
    case none
}

// MARK: - Mapper

/// Maps a value from an input type. Generic function wrapper.
public struct Mapper<T, K> {
    public let map: (T) -> K
    public init(_ map: @escaping (T) -> K) { self.map = map }
    public func callAsFunction(_ input: T) -> K { map(input) }
}

/// Resolves a value based on the current UI state.
public typealias StateProperty<T> = Mapper<UIState, T>

public extension StateProperty {
    /// Constant value regardless of state.
    static func constant(_ value: K) -> StateProperty<K> {
        StateProperty { _ in value }
    }
}
