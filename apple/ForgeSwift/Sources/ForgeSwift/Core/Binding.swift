//
//  Binding.swift
//  ForgeSwift
//
//  Two-way binding to a value. Input components (TextField, Slider,
//  Switch, Stepper, etc.) receive a Binding<T> and both read and
//  write the underlying state. Writes flow through the binding's
//  setter, which in the usual case calls rebuild { ... } on a
//  ViewModel — so the owning composite node is marked dirty and
//  the subtree updates automatically.
//
//  Usage from a ViewBuilder subclass (keypath-based convenience):
//
//      class FormModel: ViewModel {
//          var text = ""
//      }
//
//      class FormBuilder: ViewBuilder<FormModel> {
//          override func build(context: BuildContext) -> any View {
//              TextField(text: bind(\.text))
//          }
//      }
//
//  Or manually for cases where a keypath doesn't fit (computed
//  values, state outside a ViewModel, etc.):
//
//      Binding(
//          get: { currentValue },
//          set: { newValue in /* apply it somewhere */ }
//      )
//
//  Bindings are ephemeral — create them inside build(), don't cache
//  them on the ViewModel. They're cheap (two closures in a struct)
//  and each rebuild creates a fresh one that closes over the current
//  state. The backing state is what persists, not the Binding.
//

@MainActor public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var value: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
}
