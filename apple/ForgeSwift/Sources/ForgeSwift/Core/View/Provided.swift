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
//  if the value itself conforms to AnyObservable — e.g. a store).
//
//  Subscriptions live on the consumer's Node and are auto-cancelled
//  on the next build pass, same as Node.watch(observable).
//

// MARK: - Slot

/// Type-erased base so Node can store mixed-T slots in one dict.
@MainActor public protocol AnyProvidedSlot: AnyObject {}

/// Per-provider storage cell. The Observable wrapper is what makes
/// "the provider replaced its value" reactive — consumers subscribe
/// to it via Node.watch, so a slot write fires consumer rebuilds.
@MainActor public final class ProvidedSlot<T>: AnyProvidedSlot {
    public let observable: Observable<T>

    public init(_ value: T) {
        self.observable = Observable(value)
    }
}

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

    public func build(context: BuildContext) -> any View {
        // Install one slot per pack element. The repeat-in-tuple form
        // evaluates installSlot for each element; we discard the void
        // tuple result.
        let node = context.node
        _ = (repeat node.installSlot(each values))
        return child
    }
}

// MARK: - BuildContext consumer API

public extension BuildContext {
    /// Read the nearest ancestor's Provided<T> value and subscribe
    /// to slot replacement. Fatal if no provider is found — wire one
    /// at the app root, or use `maybeWatch` for optional cases.
    ///
    /// `read` registers a slot subscription only. If the value is
    /// itself an Observable (e.g. a store), use `watch` to also
    /// subscribe to its in-place mutations.
    func read<T>(_ type: T.Type) -> T {
        guard let slot = node.findSlot(type) else {
            fatalError("No Provided<\(T.self)> found in ancestors. " +
                       "Wrap your subtree in Provided(\(T.self)(...)) { ... }, " +
                       "or use maybeWatch(\(T.self).self) for optional access.")
        }
        return node.watch(slot.observable)
    }

    /// Like `read`, but additionally subscribes to the value's own
    /// observations if it conforms to AnyObservable. Use this when the
    /// provided value is a store you mutate in place — `read` only
    /// catches whole-value swaps at the provider; `watch` catches both.
    func watch<T>(_ type: T.Type) -> T {
        guard let slot = node.findSlot(type) else {
            fatalError("No Provided<\(T.self)> found in ancestors. " +
                       "Wrap your subtree in Provided(\(T.self)(...)) { ... }, " +
                       "or use maybeWatch(\(T.self).self) for optional access.")
        }
        let value = node.watch(slot.observable)
        if let observable = value as? AnyObservable {
            node.watchAny(observable)
        }
        return value
    }

    /// Optional read — returns nil if no ancestor provides T. Same
    /// subscription behavior as `watch` (slot + value-observable).
    func maybeWatch<T>(_ type: T.Type) -> T? {
        guard let slot = node.findSlot(type) else { return nil }
        let value = node.watch(slot.observable)
        if let observable = value as? AnyObservable {
            node.watchAny(observable)
        }
        return value
    }
}
