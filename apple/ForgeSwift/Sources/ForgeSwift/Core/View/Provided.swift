//
//  Provided.swift
//  ForgeSwift
//
//  Provider/Consumer pattern (Flutter's InheritedWidget /
//  React's Context).
//
//  A Provided<T> view installs a value of type T into its node's slot
//  table. Descendants read it via BuildContext.read / .watch, which
//  walk the parent chain to find the nearest provider and subscribe
//  to slot changes (and, for .watch, to the value's own observations
//  if the value itself conforms to Listenable — e.g. a store).
//
//  Subscriptions live on the consumer's Node and are auto-cancelled
//  on the next build pass, same as Node.watch(observable).
//

// MARK: - Provided

/// A view that injects one or more values into its subtree.
/// Descendants read each value via `context.read(T.self)` or
/// `context.watch(T.self)`. Lookup is by exact type — keying is per-
/// element-type, so each provided value must have a distinct static
/// type (two `Theme`s in one `Provided(...)` would collide).
///
///     Provided(theme) {
///         AppRoot()
///     }
///
///     Provided(theme, locale, session) {
///         AppRoot()
///     }
///
/// On first build the slot for each value is created; on subsequent
/// rebuilds each slot's value is updated (which fires consumer
/// rebuilds for that type).
public struct Provided<each T>: BuiltView {
    public let values: (repeat each T)
    public let child: any View

    public init(_ values: repeat each T, @ChildBuilder child: () -> any View) {
        self.values = (repeat each values)
        self.child = child()
    }

    public func build(context: ViewContext) -> any View {
        // Install one slot per pack element. The repeat-in-tuple form
        // evaluates installSlot for each element; we discard the void
        // tuple result. `installSlot` is a Node-level API and not on
        // ViewContext's public surface — we force-cast because the
        // framework only ever hands Node instances as `context`.
        guard let node = context as? Node else { return child }
        _ = (repeat node.installSlot(each values))
        return child
    }
}

// MARK: - Slot

/// Per-provider storage cell. The Observable wrapper is what makes
/// "the provider replaced its value" reactive — consumers subscribe
/// to it via Node.watch, so a slot write fires consumer rebuilds.
@MainActor public final class ProvidedSlot<T>: AnyProvidedSlot {
    public let observable: Observable<T>

    public init(_ value: T) {
        self.observable = Observable(value)
    }
}

/// Type-erased base so Node can store mixed-T slots in one dict.
@MainActor public protocol AnyProvidedSlot: AnyObject {}

// The ViewContext Provided-slot lookup methods live on Node itself
// (see `Node+ViewContext.swift` — or an extension inside Node.swift
// if not split). The old `extension ViewContext { func read/watch/...
// { ... } }` is gone: with ViewContext as a protocol and Node as its
// sole in-module conformer, implementing the methods directly on
// Node is cleaner and avoids exposing `node: Node` through the
// protocol surface.
