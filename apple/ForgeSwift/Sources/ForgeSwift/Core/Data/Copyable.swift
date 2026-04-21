//
//  Copyable.swift
//  ForgeSwift
//
//  Protocol for value types that need closure-based copy-and-mutate.
//  Gives themes, configs, and other structured values a uniform way
//  to derive a modified copy without manual field-by-field rewiring.
//
//      let custom = ColorTheme.light(seed: .blue).copy {
//          $0.surface.primary = myColor
//          $0.brand.primary = myColor.withInverse(.white)
//      }
//

/// Protocol enabling closure-based copy-and-mutate for value types.
public protocol Copyable {
    func copy(_ transform: (inout Self) -> Void) -> Self
}

public extension Copyable {
    /// Returns a copy of `self` after applying `transform` to the
    /// mutable copy. Requires all relevant fields to be declared as
    /// `var` on the conforming type.
    func copy(_ transform: (inout Self) -> Void) -> Self {
        var copy = self
        transform(&copy)
        return copy
    }
}
