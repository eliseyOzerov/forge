//
//  Spacing.swift
//  ForgeSwift
//
//  Token-tier spacing ramp. Built-in tokens xxs..xl5 as static members;
//  extend via `extension SpacingToken`. Portable — no UIKit.
//

import Foundation

// MARK: - SpacingToken

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

// MARK: - SpacingTheme

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
