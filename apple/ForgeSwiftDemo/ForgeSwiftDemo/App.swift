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
// Tap-driven composite using the ViewModel + rebuild { ... } pattern.
// CounterModel holds plain state (`var count = 0`), mutates it via
// `rebuild { }`, which triggers the owning node to re-run its build.
// CounterBuilder reads `model.count` directly — no observable, no
// subscription, no watch.

final class CounterModel: ViewModel {
    var count = 0

    func increment() {
        rebuild { count += 1 }
    }
}

final class CounterBuilder: ViewBuilder<CounterModel> {
    override func build(context: BuildContext) -> any View {
        Button("Tapped \(model.count) times") { [weak model] in
            model?.increment()
        }
    }
}

struct Counter: ModelView {
    func makeModel(context: BuildContext) -> CounterModel {
        CounterModel()
    }

    func makeBuilder(model: CounterModel) -> Builder {
        CounterBuilder(model: model)
    }
}
