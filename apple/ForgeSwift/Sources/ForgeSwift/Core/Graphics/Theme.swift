//
//  Theme.swift
//  ForgeSwift
//
//  Theme mechanism: typed slot accessor and the tier-1 TokenTheme
//  bundle that groups color + spacing + text. Component-level themes
//  live next to their views; this file just provides the plumbing.
//
//  Portable — no UIKit dependency.
//

// MARK: - ThemeSlot

/// Phantom-typed slot marker. Carries the theme type so
/// `ctx.theme(.x)` can return it without an explicit generic
/// argument at the call site.
public struct ThemeSlot<T>: Sendable {
    public let type: T.Type
    public init(_ type: T.Type) { self.type = type }
}

public extension ThemeSlot where T == TokenTheme {
    static var tokens: ThemeSlot<TokenTheme> { .init(TokenTheme.self) }
}

public extension ThemeSlot where T == ColorTheme {
    static var color: ThemeSlot<ColorTheme> { .init(ColorTheme.self) }
}

public extension ThemeSlot where T == SpacingTheme {
    static var spacing: ThemeSlot<SpacingTheme> { .init(SpacingTheme.self) }
}

public extension ThemeSlot where T == TextTheme {
    static var text: ThemeSlot<TextTheme> { .init(TextTheme.self) }
}

public extension ThemeSlot where T == WeightScale {
    static var weight: ThemeSlot<WeightScale> { .init(WeightScale.self) }
}

// MARK: - BuildContext accessor

public extension ViewContext {
    /// Typed theme lookup. Always watches — theme changes fire
    /// consumer rebuilds. Use `read(T.self)` for non-subscribing
    /// access when you have a reason to skip reactivity.
    func theme<T>(_ slot: ThemeSlot<T>) -> T {
        watch(T.self)
    }
}

// MARK: - TokenTheme

/// Foundation theme bundle. Inject once at the app root; view-level
/// themes derive from this.
///
///     Provided(TokenTheme.light()) { AppRoot() }
///
/// Consumer side:
///
///     let spacing = ctx.theme(.spacing)
///     let label   = ctx.theme(.color).label.primary
public struct TokenTheme: Sendable, Copyable {
    public var color: ColorTheme
    public var spacing: SpacingTheme
    public var text: TextTheme
    public var weight: WeightScale

    public init(color: ColorTheme, spacing: SpacingTheme, text: TextTheme, weight: WeightScale = .standard()) {
        self.color = color
        self.spacing = spacing
        self.text = text
        self.weight = weight
    }

    public static func light(brand: Color? = nil) -> TokenTheme {
        TokenTheme(
            color: .light(brand: brand),
            spacing: .standard(),
            text: .standard()
        )
    }

    public static func dark(brand: Color? = nil) -> TokenTheme {
        TokenTheme(
            color: .dark(brand: brand),
            spacing: .standard(),
            text: .standard()
        )
    }
}
