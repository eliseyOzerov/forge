//
//  Tokens.swift
//  ForgeSwift
//
//  Shared token primitives used across the theme system — named keys
//  with optional intrinsic defaults, sparse override storage, and the
//  priority/status bundles that compose on top.
//
//  Nothing here depends on UIKit; lives in Core/Graphics so any subsystem
//  (theme, component style, app config) can key off the same shape.
//

import Foundation

// MARK: - NamedKey

/// Hashable-by-name marker. Use when a key has no intrinsic default
/// value — the consumer decides what "unset" means.
public protocol NamedKey: Hashable, Sendable {
    var name: String { get }
}

public extension NamedKey {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

// MARK: - TokenKey

/// NamedKey that carries an intrinsic default value. The open-token
/// pattern: custom tokens resolve to their intrinsic default when
/// the theme doesn't override them.
public protocol TokenKey: NamedKey {
    associatedtype Value: Sendable
    var defaultValue: Value { get }
}

// MARK: - TokenMap

/// Sparse override storage for TokenKey families. Stores only the
/// overridden entries; `subscript` falls back to `key.defaultValue`.
public struct TokenMap<K: TokenKey>: Sendable, Copyable {
    public var values: [K: K.Value]

    public init(_ values: [K: K.Value] = [:]) {
        self.values = values
    }

    public subscript(_ key: K) -> K.Value {
        get { values[key] ?? key.defaultValue }
        set { values[key] = newValue }
    }

    public var count: Int { values.count }
    public var keys: Dictionary<K, K.Value>.Keys { values.keys }
    public var isEmpty: Bool { values.isEmpty }
}

// MARK: - PriorityLevel

/// Named priority level token.
public struct PriorityLevel: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension PriorityLevel {
    static let primary    = PriorityLevel("primary")
    static let secondary  = PriorityLevel("secondary")
    static let tertiary   = PriorityLevel("tertiary")
    static let quaternary = PriorityLevel("quaternary")

    /// Default cascade order. Lookup for level N walks back through
    /// earlier populated levels until it hits `.primary`.
    static let defaultChain: [PriorityLevel] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - PriorityTokens

/// Four-level (extensible) priority stack with cascade. `primary` is
/// required; higher levels optional and fall back through `chain`.
/// Sendable when `V: Sendable` — so `PriorityTokens<Color>` is
/// Sendable but `PriorityTokens<ButtonStyle>` (MainActor-only) isn't.
public struct PriorityTokens<V>: Copyable {
    public var values: [PriorityLevel: V]
    public var chain: [PriorityLevel]

    public init(
        values: [PriorityLevel: V],
        chain: [PriorityLevel] = PriorityLevel.defaultChain
    ) {
        precondition(values[.primary] != nil, "PriorityTokens requires `.primary`")
        self.values = values
        self.chain = chain
    }

    public init(primary: V, secondary: V? = nil, tertiary: V? = nil, quaternary: V? = nil) {
        var map: [PriorityLevel: V] = [.primary: primary]
        if let s = secondary  { map[.secondary]  = s }
        if let t = tertiary   { map[.tertiary]   = t }
        if let q = quaternary { map[.quaternary] = q }
        self.values = map
        self.chain = PriorityLevel.defaultChain
    }

    /// Lookup with cascade — unset levels fall back through `chain`
    /// to `.primary`.
    public subscript(_ level: PriorityLevel) -> V {
        if let v = values[level] { return v }
        if let idx = chain.firstIndex(of: level) {
            for i in stride(from: idx - 1, through: 0, by: -1) {
                if let v = values[chain[i]] { return v }
            }
        }
        return values[.primary]!
    }

    public var primary: V    { self[.primary] }
    public var secondary: V  { self[.secondary] }
    public var tertiary: V   { self[.tertiary] }
    public var quaternary: V { self[.quaternary] }
}

extension PriorityTokens: Sendable where V: Sendable {}

// MARK: - Status

/// Named status token (success, warning, error, info).
public struct Status: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension Status {
    static let success = Status("success")
    static let warning = Status("warning")
    static let error   = Status("error")
    static let info    = Status("info")
}

// MARK: - StatusTokens

/// Named statuses keyed to values. All four built-in statuses are
/// required at construction; subscript access is optional for
/// user-added custom statuses.
public struct StatusTokens<V>: Copyable {
    public var values: [Status: V]

    public init(values: [Status: V]) {
        precondition(values[.success] != nil, "StatusTokens requires `.success`")
        precondition(values[.warning] != nil, "StatusTokens requires `.warning`")
        precondition(values[.error]   != nil, "StatusTokens requires `.error`")
        precondition(values[.info]    != nil, "StatusTokens requires `.info`")
        self.values = values
    }

    public init(success: V, warning: V, error: V, info: V) {
        self.values = [.success: success, .warning: warning, .error: error, .info: info]
    }

    public subscript(_ status: Status) -> V? {
        values[status]
    }

    public var success: V { values[.success]! }
    public var warning: V { values[.warning]! }
    public var error: V   { values[.error]! }
    public var info: V    { values[.info]! }
}

extension StatusTokens: Sendable where V: Sendable {}

// MARK: - Dictionary cascade helper

public extension Dictionary where Key: NamedKey {
    /// Walks back through `chain` from `key` to the earliest populated
    /// entry. Returns `nil` if no ancestor in the chain has a value.
    /// Used by component themes to implement priority-style cascade
    /// on plain `[XRole: XStyle]` storage.
    func cascade(_ key: Key, chain: [Key]) -> Value? {
        if let v = self[key] { return v }
        guard let idx = chain.firstIndex(of: key) else { return nil }
        for i in stride(from: idx - 1, through: 0, by: -1) {
            if let v = self[chain[i]] { return v }
        }
        return nil
    }
}

// MARK: - SpacingToken

/// Named spacing value token for the spacing ramp.
public struct SpacingToken: TokenKey {
    public let name: String
    public let defaultValue: Double

    public init(_ name: String, _ defaultValue: Double) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension SpacingToken {
    static let xxs = SpacingToken("xxs",   4)
    static let xs  = SpacingToken("xs",    8)
    static let sm  = SpacingToken("sm",   12)
    static let rg  = SpacingToken("rg",   16)
    static let md  = SpacingToken("md",   20)
    static let lg  = SpacingToken("lg",   24)
    static let xl  = SpacingToken("xl",   32)
    static let xl2 = SpacingToken("xl2",  48)
    static let xl3 = SpacingToken("xl3",  64)
    static let xl4 = SpacingToken("xl4",  96)
    static let xl5 = SpacingToken("xl5", 128)
}

/// Theme collection of spacing tokens.
public struct SpacingTheme: Sendable, Copyable {
    public var values: TokenMap<SpacingToken>

    public init(values: TokenMap<SpacingToken> = TokenMap()) {
        self.values = values
    }

    public subscript(_ token: SpacingToken) -> Double { values[token] }

    public var xxs: Double { self[.xxs] }
    public var xs:  Double { self[.xs] }
    public var sm:  Double { self[.sm] }
    public var rg:  Double { self[.rg] }
    public var md:  Double { self[.md] }
    public var lg:  Double { self[.lg] }
    public var xl:  Double { self[.xl] }
    public var xl2: Double { self[.xl2] }
    public var xl3: Double { self[.xl3] }
    public var xl4: Double { self[.xl4] }
    public var xl5: Double { self[.xl5] }

    /// Built-in ramp — every named token populated with its default.
    public static func standard() -> SpacingTheme {
        var map: [SpacingToken: Double] = [:]
        for token in [SpacingToken.xxs, .xs, .sm, .rg, .md, .lg, .xl, .xl2, .xl3, .xl4, .xl5] {
            map[token] = token.defaultValue
        }
        return SpacingTheme(values: TokenMap(map))
    }
}

// MARK: - WeightToken

/// Named weight token mapping a semantic Weight case to a numeric value (CSS-style 100–900).
public struct WeightToken: TokenKey {
    public let name: String
    public let defaultValue: Int

    public init(_ name: String, _ defaultValue: Int) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension WeightToken {
    static let ultraLight = WeightToken("ultraLight", 100)
    static let thin       = WeightToken("thin",       200)
    static let light      = WeightToken("light",      300)
    static let regular    = WeightToken("regular",    400)
    static let medium     = WeightToken("medium",     500)
    static let semibold   = WeightToken("semibold",   600)
    static let bold       = WeightToken("bold",       700)
    static let heavy      = WeightToken("heavy",      800)
    static let black      = WeightToken("black",      900)
}

// MARK: - WeightScale

/// Maps Weight → numeric value → stroke thickness in points.
/// Semantic weights resolve through `values` (a TokenMap of WeightToken).
/// Numeric weights resolve through `thicknessMap` with linear interpolation
/// between entries.
public struct WeightScale: Sendable, Copyable {
    public var values: TokenMap<WeightToken>
    public var thicknessMap: [Int: Double]

    public init(
        values: TokenMap<WeightToken> = TokenMap(),
        thicknessMap: [Int: Double] = [100: 0.5, 400: 1.5, 700: 2.5, 900: 3.5]
    ) {
        self.values = values
        self.thicknessMap = thicknessMap
    }

    /// Resolve a Weight to its numeric value via the token map.
    public func numericValue(for weight: Weight) -> Int {
        switch weight {
        case .ultraLight: values[.ultraLight]
        case .thin:       values[.thin]
        case .light:      values[.light]
        case .regular:    values[.regular]
        case .medium:     values[.medium]
        case .semibold:   values[.semibold]
        case .bold:       values[.bold]
        case .heavy:      values[.heavy]
        case .black:      values[.black]
        case .numeric(let n): n
        }
    }

    /// Resolve a Weight to stroke thickness in points. Interpolates
    /// linearly between the nearest entries in `thicknessMap`.
    public func thickness(for weight: Weight) -> Double {
        let numeric = numericValue(for: weight)
        return interpolateThickness(numeric)
    }

    private func interpolateThickness(_ numeric: Int) -> Double {
        let sorted = thicknessMap.sorted { $0.key < $1.key }
        guard !sorted.isEmpty else { return 1.5 }

        if let exact = thicknessMap[numeric] { return exact }
        if numeric <= sorted.first!.key { return sorted.first!.value }
        if numeric >= sorted.last!.key { return sorted.last!.value }

        var lower = sorted[0]
        var upper = sorted[sorted.count - 1]
        for entry in sorted {
            if entry.key <= numeric { lower = entry }
            if entry.key >= numeric { upper = entry; break }
        }

        let t = Double(numeric - lower.key) / Double(upper.key - lower.key)
        return lower.value + t * (upper.value - lower.value)
    }

    public static func standard() -> WeightScale {
        WeightScale()
    }
}
