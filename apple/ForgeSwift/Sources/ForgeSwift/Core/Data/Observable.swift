//
//  Observable.swift
//  SwiftKit
//
//  The reactive primitive. Models expose Observables on their data
//  protocol so Builders can read-and-subscribe in a single explicit
//  call via `node.watch(...)`.
//
//  Lifecycle: subscriptions are stored on the owning Node and cancelled
//  when the Node unmounts. Callers don't need to hold Subscriptions
//  themselves — hand them to the Node.
//

/// Type-erased view of an Observable. Lets generic code (e.g.
/// BuildContext.watch) subscribe to changes without knowing the
/// element type. Observable<T> conforms automatically.
@MainActor public protocol AnyObservable {
    func observeChange(_ callback: @escaping @MainActor () -> Void) -> Subscription
}

@MainActor @propertyWrapper
public final class Observable<T>: AnyObservable {
    private var _value: T
    private var nextId: Int = 0
    private var observers: [Int: @MainActor (T) -> Void] = [:]

    public init(_ value: T) {
        self._value = value
    }

    public convenience init(wrappedValue: T) {
        self.init(wrappedValue)
    }

    public var wrappedValue: T {
        get { _value }
        set { value = newValue }
    }

    public var projectedValue: Binding<T> { binding }

    public var value: T {
        get { _value }
        set {
            _value = newValue
            // Snapshot before iterating: observer callbacks may trigger
            // rebuilds that cancel subscriptions, mutating `observers` —
            // iterating a Dictionary while mutating it is UB in Swift.
            let snapshot = Array(observers.values)
            for observer in snapshot {
                observer(newValue)
            }
        }
    }

    public func observe(_ callback: @escaping @MainActor (T) -> Void) -> Subscription {
        let id = nextId
        nextId += 1
        observers[id] = callback
        return Subscription { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func observeChange(_ callback: @escaping @MainActor () -> Void) -> Subscription {
        observe { _ in callback() }
    }
}

// MARK: - Observable → Binding

public extension Observable {
    /// Create a Binding backed by this Observable's value.
    /// Usage: `TextField(text: name.binding)` where `name` is an `Observable<String>`.
    var binding: Binding<T> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

// MARK: - Subscription

@MainActor public final class Subscription {
    private var cancelClosure: (() -> Void)?

    init(cancel: @escaping () -> Void) {
        self.cancelClosure = cancel
    }

    public func cancel() {
        cancelClosure?()
        cancelClosure = nil
    }
}
