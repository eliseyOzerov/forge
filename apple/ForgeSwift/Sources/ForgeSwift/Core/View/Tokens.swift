//
//  Tokens.swift
//  ForgeSwift
//
//  Shared token primitives used across the theme system — named keys
//  with optional intrinsic defaults, sparse override storage, and the
//  priority/status bundles that compose on top.
//
//  Nothing here depends on UIKit; lives in Core/View so any subsystem
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
