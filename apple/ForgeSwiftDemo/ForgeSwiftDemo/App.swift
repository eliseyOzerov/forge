//
//  App.swift
//  ForgeSwiftDemo
//

import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Shuffler()
    }
}

// MARK: - Shuffler

struct Shuffler: ModelView {
    func makeModel(context: BuildContext) -> ShuffleModel { ShuffleModel() }
    func makeBuilder() -> ShuffleBuilder { ShuffleBuilder() }
}

final class ShuffleModel: ViewModel<Shuffler> {
    var ids: [Int] = [1, 2, 3, 4]

    func shuffle() {
        rebuild { ids.shuffle() }
    }
}

final class ShuffleBuilder: ViewBuilder<ShuffleModel> {
    override func build(context: BuildContext) -> any View {
        VStack(spacing: 12) {
            for id in model.ids {
                ItemCounter(tag: id)
            }
            Button("Shuffle") { [weak model] in
                model?.shuffle()
            }
        }
    }
}

// MARK: - ItemCounter

struct ItemCounter: ModelView {
    let tag: Int

    func makeModel(context: BuildContext) -> ItemCounterModel { ItemCounterModel() }
    func makeBuilder() -> ItemCounterBuilder { ItemCounterBuilder() }
}

final class ItemCounterModel: ViewModel<ItemCounter> {
    var tag: Int = 0
    var count = 0

    override func didInit() {
        tag = view.tag
    }

    override func didUpdate(from oldView: ItemCounter) {
        tag = view.tag
    }

    func increment() {
        rebuild { count += 1 }
    }
}

final class ItemCounterBuilder: ViewBuilder<ItemCounterModel> {
    override func build(context: BuildContext) -> any View {
        Button("Counter \(model.tag): \(model.count) taps") { [weak model] in
            model?.increment()
        }
    }
}
