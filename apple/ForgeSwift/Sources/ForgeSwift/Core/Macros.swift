// MARK: - Individual macros

/// Generates a public memberwise initializer and static per-property factories.
@attached(member, names: named(init), arbitrary)
public macro Init() = #externalMacro(module: "ForgeSwiftMacros", type: "InitMacro")

/// Generates a fluent copy method for each stored property.
@attached(member, names: arbitrary)
public macro Copy() = #externalMacro(module: "ForgeSwiftMacros", type: "CopyMacro")

/// Generates `merge(_ other:)` — `self.property ?? other.property`.
@attached(member, names: named(merge))
@attached(extension, conformances: Mergeable)
public macro Merge() = #externalMacro(module: "ForgeSwiftMacros", type: "MergeMacro")

/// Generates `lerp(to:t:)` — lerps Lerpable fields, snaps the rest.
/// Mark non-lerpable fields with `@Snap`.
@attached(member, names: named(lerp))
@attached(extension, conformances: Lerpable)
public macro Lerp() = #externalMacro(module: "ForgeSwiftMacros", type: "LerpMacro")

/// Generates `toMap() -> [String: Any]` and `init(map:)`.
@attached(member, names: named(toMap), named(init))
public macro Map() = #externalMacro(module: "ForgeSwiftMacros", type: "MapMacro")

/// Generates `toJson() -> String` and `init(json:)`.
@attached(member, names: named(toJson), named(init))
public macro Json() = #externalMacro(module: "ForgeSwiftMacros", type: "JsonMacro")

/// Generates `CustomStringConvertible` conformance with a description listing all properties.
@attached(member, names: named(description))
@attached(extension, conformances: CustomStringConvertible)
public macro String() = #externalMacro(module: "ForgeSwiftMacros", type: "StringMacro")

// MARK: - Composites

/// `@Init` + `@Copy` + `@Merge`.
@attached(member, names: named(init), named(merge), arbitrary)
@attached(extension, conformances: Mergeable)
public macro Data() = #externalMacro(module: "ForgeSwiftMacros", type: "DataMacro")

/// `@Data` + `@Lerp` — full style struct support.
@attached(member, names: named(init), named(merge), named(lerp), arbitrary)
@attached(extension, conformances: Mergeable, Lerpable)
public macro Style() = #externalMacro(module: "ForgeSwiftMacros", type: "StyleMacro")

// MARK: - Protocol macros

/// Generates an `AnyX` type-erased wrapper for a protocol.
@attached(peer, names: prefixed(Any))
public macro Erased() = #externalMacro(module: "ForgeSwiftMacros", type: "ErasedMacro")

// MARK: - Field markers

/// Marks a field as non-lerpable — snaps instead of interpolating.
@attached(peer)
public macro Snap() = #externalMacro(module: "ForgeSwiftMacros", type: "SnapMacro")
