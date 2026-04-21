// MARK: - Observable

/// A Notifier that holds a value. Notifies on set.
/// `observe` gives you the new value; `listen` just tells you something changed.
@MainActor @propertyWrapper
public class Observable<T>: Notifier {
    private var _value: T
    private var nextObserverId: Int = 0
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
            // Observers first (typed), then listeners (untyped).
            let snapshot = Array(observers.values)
            for observer in snapshot {
                observer(newValue)
            }
            notify()
        }
    }

    /// Typed subscribe — callback receives the new value.
    public func observe(_ callback: @escaping @MainActor (T) -> Void) -> Subscription {
        let id = nextObserverId
        nextObserverId += 1
        observers[id] = callback
        return Subscription { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

// MARK: - Observable → Binding

public extension Observable {
    var binding: Binding<T> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

// MARK: - Notifier

/// Concrete notification engine. Stores listeners, fires them on `notify()`.
@MainActor
public class Notifier: Listenable {
    private var nextId: Int = 0
    private var listeners: [Int: @MainActor () -> Void] = [:]

    public init() {}

    public func listen(_ callback: @escaping @MainActor () -> Void) -> Subscription {
        let id = nextId
        nextId += 1
        listeners[id] = callback
        return Subscription { [weak self] in
            self?.listeners.removeValue(forKey: id)
        }
    }

    public func notify() {
        let snapshot = Array(listeners.values)
        for listener in snapshot {
            listener()
        }
    }
}

// MARK: - Listenable

/// Something you can subscribe to for change notifications.
@MainActor public protocol Listenable {
    func listen(_ callback: @escaping @MainActor () -> Void) -> Subscription
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
