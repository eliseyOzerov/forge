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
//
// Parent composite with a shuffleable list of per-row counters.
// Each row is a stateful ItemCounter (its own ModelView with its
// own count). The list is identified by `.id(_:)` so ContainerNode's
// reconciler preserves each counter's identity (and state) across
// reorders.
//
// To see the effect of ids: tap a few counters to different values,
// then shuffle. Each counter's count should *travel with its tag* —
// Counter 3 at position 0 still says "Counter 3: N taps" with the
// N it was tapped to.
//
// Contrast: remove `.id(id)` from the ItemCounter line below and
// rerun. The reconciler falls back to position + type matching, so
// a shuffle leaves the counts at their *positions* rather than with
// their logical identities — you'll see "Counter 3: 0 taps" at slot
// 0 because the tag prop gets overwritten but the model state stays
// put at its old slot.

final class ShuffleModel: ViewModel {
    var ids: [Int] = [1, 2, 3, 4]

    func shuffle() {
        rebuild { ids.shuffle() }
    }
}

final class ShuffleBuilder: ViewBuilder<ShuffleModel> {
    override func build(context: BuildContext) -> any View {
        VStack(spacing: 12) {
            for id in model.ids {
                ItemCounter(tag: id).id(id)
            }
            Button("Shuffle") { [weak model] in
                model?.shuffle()
            }
        }
    }
}

struct Shuffler: ModelView {
    func makeModel(context: BuildContext) -> ShuffleModel { ShuffleModel() }
    func makeBuilder(model: ShuffleModel) -> Builder { ShuffleBuilder(model: model) }
}

// MARK: - ItemCounter
//
// Per-row stateful counter. Holds its own count; the `tag` prop is
// passed down from the parent and identifies the row visually.
// When the parent re-renders with a new tag for the same id (not
// used in this demo, but the path exists), the builder is remade
// via ComposedNode.remakeBuilder while preserving the model state.

final class ItemCounterModel: ViewModel {
    var count = 0

    func increment() {
        rebuild { count += 1 }
    }
}

final class ItemCounterBuilder: ViewBuilder<ItemCounterModel> {
    let tag: Int

    init(model: ItemCounterModel, tag: Int) {
        self.tag = tag
        super.init(model: model)
    }

    override func build(context: BuildContext) -> any View {
        Button("Counter \(tag): \(model.count) taps") { [weak model] in
            model?.increment()
        }
    }
}

struct ItemCounter: ModelView {
    let tag: Int

    init(tag: Int) {
        self.tag = tag
    }

    func makeModel(context: BuildContext) -> ItemCounterModel {
        ItemCounterModel()
    }

    func makeBuilder(model: ItemCounterModel) -> Builder {
        ItemCounterBuilder(model: model, tag: tag)
    }
}
