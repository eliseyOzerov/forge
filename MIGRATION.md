# View Protocol Migration

## Status

**Phases 1–3 + 5 shipped** (BuiltView/ModelView rename, Node split, new ViewLifecycle/ViewBuilding protocols with ViewModel/ViewBuilder default classes, all 8 ModelView conformances migrated, old inheritance base classes deleted). Build clean, 943/943 tests green on iPhone 17 Pro sim.

**Phase 4 (RouteView)** and **Phase 6 (formalized Provided slot API on RouteHandle)** deferred. The current `Route` protocol + `RouterHandle` still work as-is.

Keep this file until the remaining phases land; then delete.

## Goal

Replace inheritance-based model wiring (`ViewModelBase`/`ViewModel<V>` class / `ViewBuilder<T>` class) with protocol contracts + optional default base classes, and split the top-level protocols + their Node backings for clarity.

## Target shape

Four sibling protocols under `View`:

- `LeafView` — native primitive, no children (unchanged).
- `BuiltView` — pure composition via `build(context:) -> any View` (**renamed** from `ComposedView`). Backed by `BuiltNode`, which stores no per-instance data and has no user-triggered rebuild path. Still wires `onDirty` so upstream observable emissions (Provided changes, `context.watch`) re-run its build.
- `ModelView` — local state; `model(context:) -> Model` + `builder(model:) -> Builder`. `Model: ViewLifecycle<Self>`, `Builder: ViewBuilding<Model>`. Backed by `ModelNode`, which stores the Model and dispatches its lifecycle.
- `RouteView` — screens; same shape as ModelView plus `navigationItem` + `presentation`, with service access via `RouteHandle<Self>`. **Replaces today's `Route` protocol.** (Scope untouched this pass — Phase 4 work is still planned but not actively being reworked.)

### `ViewLifecycle` protocol + `ViewModel<View>` default class

The lifecycle contract is a protocol; the framework ships a default class that most Models subclass.

```swift
public protocol ViewLifecycle<View>: AnyObject {
    associatedtype View
    func didInit(view: View)
    func didUpdate(newView: View)
    func didRebuild()
    func didDispose()
}
// All four have default-empty implementations on a protocol extension.

open class ViewModel<View>: ViewLifecycle {
    public let context: BuildContext
    public private(set) var view: View!
    public init(context: BuildContext)
    // Default didInit stashes view; default didUpdate replaces view.
    // Default didRebuild / didDispose are no-ops.
    public func rebuild(_ mutation: () -> Void)  // forwards to context.rebuild
}
```

Subclassing `ViewModel<View>` gives you `self.view`, `self.context`, and `rebuild { }` for free. Conform to `ViewLifecycle` directly if you need full control (no auto-stash, different init signature, etc.).

### `ViewBuilding` protocol + `ViewBuilder<Model>` default class

```swift
public protocol ViewBuilding<Model> {
    associatedtype Model
    func build(context: BuildContext) -> any View
}

open class ViewBuilder<Model>: ViewBuilding {
    public let model: Model
    public init(model: Model)
    // open func build(context:) — subclass overrides.
}
```

### `didUpdate` single-arg shape

The original spec had `didUpdate(oldView:newView:)`. Shipped shape drops the old-view parameter: `didUpdate(newView:)`. Conformers that want to diff old vs new can access the previous value via `self.view` (on the default class — it still holds the previous view until `super.didUpdate(newView:)` assigns the new one) or via their own stash (on direct `ViewLifecycle` conformers).

### Node split

- `BuiltNode` — stateless. No dirty flag, no Model slot, no rebuild trigger. Rebuilds only happen as a consequence of an ancestor `ModelNode` re-rendering.
- `ModelNode` — stores the Model, dispatches `ViewModel` lifecycle, owns dirty state and rebuild plumbing. This is the only node that can be marked dirty from within the tree.
- `LeafNode` — unchanged; framework-managed native view state.

## Phases

### Phase 1 — Extend `BuildContext` + introduce `RouteHandle` (non-breaking)

- [ ] Add `rebuild(_ mutation: () -> Void)` to `BuildContext`. Sandwich-style: framework executes the mutation closure, then marks the owning `ModelNode` dirty. Needed before Phase 3 can land.
- [ ] Add `RouteHandle<V>` struct (composes BuildContext + read, watch) — used by RouteView only.
- [ ] Wire the framework to construct the RouteHandle when building RouteView nodes.
- [ ] `ViewHandle` is **not** introduced. ModelView gets `BuildContext` directly in `model(context:)`; no separate handle type.

### Phase 2 — Rename `ComposedView` → `BuiltView`, split Node types (breaking, mechanical)

- [ ] Rename `ComposedView` → `BuiltView` across protocol and all conformances.
- [ ] Update `Buildable` struct's parent protocol reference.
- [ ] Rename the existing compositional Node → `BuiltNode`. Remove any dirty-state / rebuild plumbing from it (BuiltNode must be strictly stateless).
- [ ] Introduce `ModelNode` — holds the Model, owns the dirty flag + rebuild queue, dispatches `ViewModel` lifecycle. ModelView instances back onto `ModelNode`; BuiltView instances onto `BuiltNode`.
- [ ] Update all docs under `~/.claude/skills/forge/core/view/` and folder README.
- [ ] Sweep tests and examples.

### Phase 3 — Update `ModelView` signature + introduce `ViewModel<V>` protocol (breaking)

- [ ] Add `ViewModel<V>` protocol with default-implemented lifecycle (see "Target shape" above).
- [ ] Change `ModelView` to:
  ```swift
  public protocol ModelView: View {
      associatedtype Model: ViewModel<Self>
      associatedtype Builder: ViewBuilder<Model>
      func model(context: BuildContext) -> Model
      func builder(model: Model) -> Builder
  }
  ```
- [ ] Drop `ComposedView`/`BuiltView` conformance — delete the fatalError stub on `build(context:)`.
- [ ] Framework dispatch per `ModelNode`:
  1. At mount: call `model(context:)` once. Stash the Model on the ModelNode. Call `model.didInit(view:)`.
  2. At each render: call `builder(model:)` then `builder.build(context:)` to produce the child view subtree. Call `model.didRebuild()` after.
  3. On parent re-evaluation with new `Self` value: call `model.didUpdate(oldView:newView:)`.
  4. At unmount: call `model.didDispose()`, then discard the Model.
- [ ] Models trigger rebuilds via the captured `BuildContext` — `context.rebuild { self.count += 1 }`.
- [ ] Existing ModelView conformances migrate from `ViewModel<V>` + `ViewBuilder<T>` base classes to plain classes that conform to the new `ViewModel<V>` protocol, plus a Builder type conforming to `ViewBuilder<Model>`.

### Phase 4 — Introduce `RouteView`, retire `Route` (breaking)

- [ ] Add `RouteView` protocol with the shape above.
- [ ] Migrate existing `Route` conformances in `Components/Navigation/Route.swift`.
- [ ] Update `Router` + `RouterHandle` to accept RouteView instances (or AnyRouteView erasure) instead of `AnyRoute`.
- [ ] Delete `Route`, `AnyRoute`, `RouteBuilder` (or alias them to RouteView equivalents for one release).
- [ ] Update `ForgeHostingController` to read `view.navigationItem` / `view.presentation` directly.

### Phase 5 — Retire inheritance base classes

- [ ] Delete `ViewModelBase` and the old `Builder` protocol.
- [ ] Delete the old inheritance-based `ViewModel<V>` base class. The name is recycled as the new lifecycle protocol (Phase 3) — existing subclasses lose the `V`-typed helpers and conform to the new protocol instead.
- [ ] Convert `ViewBuilder<T>` from base class to protocol with a single requirement:
  ```swift
  public protocol ViewBuilder<Model> {
      associatedtype Model
      func build(context: BuildContext) -> any View
  }
  ```
  Existing Builder subclasses conform to the protocol; they typically hold `let model: Model` captured from `builder(model:)` and implement `build(context:)`.
- [ ] Delete the `Buildable` helper if no longer needed (it's BuiltView already).
- [ ] Remove `node` weak refs and `markDirty` plumbing that was specific to ViewModelBase — rewire through `BuildContext.rebuild` and `ModelNode`'s own dirty state.
- [ ] Remove `BuildContext.watch` comment about "vestigial" if Provided-based read/watch is promoted through RouteHandle.

### Phase 6 — Provided slot API

- [ ] Solidify the typed slot lookup used by `RouteHandle.read` and `.watch`. Current `Provided.swift` has the slot machinery; this phase wires it into the handle.
- [ ] Ensure `read` is a one-shot capture (not reactive) and `watch` subscribes for rebuild.
- [ ] Add tests for slot propagation across RouteView boundaries.

## Per-phase gates

Each phase lands as its own PR and must:

1. Build clean for iPhone 17 Pro sim.
2. Test suite green (all existing tests, plus any added for new behavior).
3. Update `~/.claude/skills/forge/core/view/*.md` + folder README for any file whose public surface changed.
4. Update `~/.claude/skills/forge/SKILL.md` cross-references if top-level concepts shifted.

## Breaking-change surface

Affects any downstream:

- All `ComposedView` conformances (rename to `BuiltView`).
- All `ModelView` conformances (new `model(context:)` + `builder(model:)` shape; Model migrates from `ViewModel<V>` base-class subclass to plain class conforming to the new `ViewModel<V>` protocol).
- All `Route` conformances (port to `RouteView` — Phase 4, still planned).
- Any direct references to the old `ViewModel<V>` base class (conform to the new `ViewModel<V>` protocol; most overrides carry over via the new default-implemented lifecycle methods) or `ViewBuilder<T>` base class (conform to `ViewBuilder<Model>` protocol; the `ViewBuilder` name itself survives).
- The Node hierarchy splits: any framework code that assumed a single Node type must now dispatch on `BuiltNode` vs `ModelNode`.

At present the only downstream is Forge's own test suite and (when it exists) WaveForge. WaveForge isn't consuming any of this yet — the migration runs ahead of WaveForge feature work, so there's no external breakage cost beyond the SDK's own tests.

## Testing expectations

After Phase 5, any Model should be unit-testable like this:

```swift
let context = StubBuildContext()
let model   = SomeModel(context: context, /* injected deps */)
model.didInit(view: .init(...))
model.someAction()
XCTAssertEqual(context.rebuildCount, 1)
```

The Builder is testable with a fake Model:

```swift
let fakeModel = SomeModel.stub(/* canned state */)
let builder   = SomeBuilder(model: fakeModel)
let output    = builder.build(context: StubBuildContext())
// assert on output
```

No Resolver, no tree, no framework harness. This is the acceptance criterion: a Model test and a Builder test that were impossible (or painful) with inheritance should be trivial after migration.

## Open questions to resolve during the work

1. `RouteHandle.read` / `.watch` slot lookup syntax — what's the actual call site look like? (`handle.read(AppStateController.self)` vs `handle.read(\.appState)` vs a `Key`-typed version.)
2. How does `AnyRouteView` (erasure) work given the associated types? Probably a wrapper class like today's `AnyRoute` but with the new shape.
3. Subscription cleanup in plain-class Models — does `didDispose` cover everything, or do we need a `CancellationScope` helper?
4. `RouteView` name is iOS-flavored ("route" is a navigation concept that doesn't map cleanly to desktop windows/tabs or web URL-plus-layout). Revisit at M3 when Android lands, not now.

Track resolutions here as they land.
