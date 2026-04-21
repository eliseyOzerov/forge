# Claude Code Instructions

## Commits

- Do NOT add "Co-Authored-By" lines to commit messages.
- Commit after completing each task (each user change request, or each step in a plan) unless instructed otherwise.
- Also commit **before** a risky or large refactor as a checkpoint.
- **Hold off** when:
  - Multiple small changes form one logical unit (e.g. move + rename + update tests).
  - The code is in a broken intermediate state.
  - The next change is trivially related to the current one.

## Building & Testing

- **Always** build and run tests before considering a task complete — no exceptions.
- **Never use `swift build` or `swift test`** — they target macOS and skip all `#if canImport(UIKit)` code, giving false confidence.
- Build for iOS Simulator: `xcodebuild build -scheme ForgeSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Run tests for iOS Simulator: `xcodebuild test -scheme ForgeSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Never commit code that doesn't compile or has failing tests.
- If implementation code was changed or added, add or update tests for that code.

## Platform Portability

Public Forge APIs must never contain platform-dependent code. This ensures portability across platforms.

- Never gate public APIs inside `canImport` statements.
- Keep `canImport` guards **at the bottom of the file**, not sprinkled throughout. If a type's methods need platform APIs, implement those methods in extensions inside the `canImport` guard at the bottom.
- **Exception:** `makeRenderer` uses `canImport` inline to select the correct platform renderer (`[Component]UIKitRenderer` or `[Component]AppKitRenderer`).

## Macros

Use Forge macros (defined in `ForgeSwiftMacros`) instead of writing boilerplate by hand. If a struct/class looks like a candidate but has exceptions, **ask the user**.

| Macro | When to use |
|-------|-------------|
| `@Init` | Almost all structs and classes — skip only when a memberwise init doesn't make sense (rare). |
| `@Copy` | Most structs (not classes — they're mutable). |
| `@Merge` | Predominantly style structs, though `@Style` already includes it. |
| `@Data` | Combines `@Init` + `@Copy` + `@Merge`. Use on non-style data structs that need all three. |
| `@Lerp` / `@Snap` | Primarily style structs for now; mark snap-not-interpolate fields with `@Snap`. |
| `@Style` | Combines `@Data` + `@Lerp`. Use on style structs. |
| `@Map` / `@Json` | Structs that make sense to persist or serialize (form data, server replies, configuration). Not every struct. |
| `@String` | Niche — useful for debugging, but not required on every struct. |
| `@Erased` | Protocols with `Self` requirements that need a type-erased wrapper. |

- If convenience initializers are needed beyond what `@Init` generates, place them in an **extension** — not in the primary declaration.

## View Data vs Style

View structs separate **data** parameters (unique to the instance) from **style** parameters (reusable presentation).

- **Data:** the content the view displays or binds to (e.g. `source`, `value`, `content`).
- **Style:** visual / behavioral knobs collected in a `[Component]Style` struct (e.g. `GraphicStyle`, `ButtonStyle`).

Every view that has a style must expose a `style(_:)` extension method that returns a copy with the style applied. The closure receives the default style (and, for inputs, the current `State`):

```swift
// Content view (no state)
public func style(_ build: (IconStyle) -> IconStyle) -> Icon { … }

// Input view (state-aware)
func style(_ build: @escaping @MainActor (ButtonStyle, State) -> ButtonStyle) -> Button { … }
```

This lets callers keep defaults and override selectively. Utility/layout views that have no meaningful visual style may omit this.

## Documentation

- Every struct, class, enum, and protocol must have a short doc comment (`///`) describing its purpose and mentioning related types that are essential to its usefulness (e.g. `ButtonStyle` on `Button`, `Source` on `SourceState`).
- A type lexicon lives at `docs/lexicon.md` — one sentence per Forge type (public or internal) plus the file path.
- When researching the SDK, **check `docs/` first** for conceptual understanding; only read source files when you need actual implementation details.

## Swift File Ordering

Each file must keep the main struct/type it represents at the top. If the filename is `Graphic.swift`, the first struct is `Graphic`. This does not apply to general library files that contain many types of equal importance.

After the core struct, place its dependencies in **breadth-first** order:
1. All types the main struct directly depends on
2. Then all types those depend on (in order)
3. And so on recursively
