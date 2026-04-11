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
// Builder returns a VStack of three children: a count label and two
// buttons. Every rebuild produces a new VStack with new Text + Button
// structs; the ContainerNode reconciles them against the existing
// child nodes — updating the Text's label in place and replacing the
// Buttons' tap handlers without tearing down the UIButtons.

final class CounterModel: ViewModel {
    var count = 0

    func increment() {
        rebuild { count += 1 }
    }

    func decrement() {
        rebuild { count -= 1 }
    }
}

final class CounterBuilder: ViewBuilder<CounterModel> {
    override func build(context: BuildContext) -> any View {
        VStack(spacing: 16, children: [
            Text("Count: \(model.count)"),
            Button("Increment") { [weak model] in model?.increment() },
            Button("Decrement") { [weak model] in model?.decrement() },
        ])
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
