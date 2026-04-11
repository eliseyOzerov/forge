//
//  App.swift
//  ForgeSwiftDemo
//

import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Counter()
    }
}

// MARK: - Counter
//
// Tap-driven composite. Proves: Button leaf, CompositeView + Model +
// Builder, Observable → markDirty → rebuild, and that the rebuild
// loop survives re-entrancy from the button's own action handler.

@MainActor
protocol CounterData: AnyObject {
    var count: Observable<Int> { get }
    func increment()
}

@MainActor
final class CounterModel: ViewModel, CounterData {
    let count = Observable(0)

    func increment() {
        count.value += 1
    }
}

@MainActor
final class CounterBuilder: Builder {
    let data: CounterData
    weak var node: Node?

    init(data: CounterData) {
        self.data = data
    }

    func build() -> any View {
        guard let node else { return Text("—") }
        let value = node.watch(data.count)
        return Button("Tapped \(value) times") { [weak data] in
            data?.increment()
        }
    }
}

struct Counter: CompositeView {
    func makeModel(node: Node) -> CounterModel {
        CounterModel()
    }

    func makeBuilder(model: CounterModel) -> Builder {
        CounterBuilder(data: model)
    }
}
