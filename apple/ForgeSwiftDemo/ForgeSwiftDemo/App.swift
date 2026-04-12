//
//  App.swift
//  ForgeSwiftDemo
//

import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Column(spacing: 24) {
            // Packed row (default), left-aligned
            label("packed, left")
            Row(spacing: 8, alignment: .centerLeft) {
                chip("A")
                chip("B")
                chip("C")
            }

            // Space between
            label("between")
            Row(spread: .between) {
                chip("1")
                chip("2")
                chip("3")
            }

            // Space around
            label("around")
            Row(spread: .around) {
                chip("X")
                chip("Y")
                chip("Z")
            }

            // Space even
            label("even")
            Row(spread: .even) {
                chip("!")
                chip("@")
                chip("#")
            }
            .debug(.red)

            // Fill child in a row
            label("fill child")
            Row(spacing: 8) {
                chip("fixed")
                Box(.width(.fill()).height(.fix(40)), .color(Color(0.2, 0.7, 0.4))) {
                    Text("fills", style: TextStyle(font: Font(size: 14), color: .white, align: .center))
                }
                chip("fixed")
            }
        }
    }

    private func label(_ text: String) -> Text {
        Text(text, style: TextStyle(font: Font(size: 12, weight: 500), color: .gray, align: .leading))
    }

    private func chip(_ text: String) -> Box {
        Box(.fixed(40, 40), .color(Color(0.2, 0.5, 1.0)), .roundedRect(radius: 8)) {
            Text(text, style: TextStyle(font: Font(size: 16, weight: 600), color: .white, align: .center))
        }
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
        Column(spacing: 12) {
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
