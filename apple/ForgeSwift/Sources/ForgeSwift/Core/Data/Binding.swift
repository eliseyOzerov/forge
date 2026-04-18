@MainActor public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    /// Create a binding backed by a mutable reference cell.
    /// Reads and writes go to the stored value directly.
    public init(_ initial: Value) {
        let storage = RefBox(initial)
        self.getter = { storage.value }
        self.setter = { storage.value = $0 }
    }

    /// Create a binding from explicit get/set closures.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var value: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    /// Returns a new binding that calls `handler` after every write.
    public func onChange(_ handler: @escaping (Value) -> Void) -> Binding {
        Binding(get: getter, set: { newValue in
            self.setter(newValue)
            handler(newValue)
        })
    }
}

/// Simple reference-type box for value storage.
private final class RefBox<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
