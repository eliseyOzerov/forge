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
            Button(
                "Tap me",
                style: StateProperty { state in
                    BoxStyle(
                        .fillWidth.height(.fix(48)),
                        state.contains(.pressed)
                            ? .color(Color(0.1, 0.4, 0.9))
                            : .color(Color(0.2, 0.5, 1.0)),
                        .capsule(),
                        padding: Padding(horizontal: 16)
                    )
                },
                onTap: { print("tapped!") }
            )

            Button(
                style: StateProperty { state in
                    BoxStyle(
                        .hug,
                        .color(state.contains(.pressed) ? Color(0.8, 0.2, 0.2) : Color(0.9, 0.3, 0.3))
                            .border(.white, width: 2),
                        .roundedRect(radius: 12),
                        padding: Padding(horizontal: 24, vertical: 12)
                    )
                },
                onTap: { print("custom body tapped!") }
            ) {
                Row(spacing: 8) {
                    Icon("star.fill", style: IconStyle(size: 18, color: .white))
                    Text("Star", style: TextStyle(font: Font(size: 16, weight: 600), color: .white))
                }
            }
        }.padded(40).centered()
    }

    private func oldBody() -> any View {
        Column(spacing: 24) {
            // Packed row (default), left-aligned
            label("packed, left")
            Row(spacing: 8, alignment: .centerLeft) {
                chip("A")
                chip("B")
                chip("C")
            }.debug(.red)

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
            

            // Fill child in a row
            label("fill child")
            Row(spacing: 8) {
                chip("fixed")
                Box(.width(.fill()).height(.fix(40)), .color(Color(0.2, 0.7, 0.4))) {
                    Text("fills", style: TextStyle(font: Font(size: 14), color: .white, align: .center))
                }
                chip("fixed")
            }

            // Multiple flex children (1:2 ratio)
            label("flex 1:2")
            Row(spacing: 8) {
                Box(.width(.fill(flex: 1)).height(.fix(40)), .color(Color(0.9, 0.3, 0.3))) {
                    Text("1", style: TextStyle(font: Font(size: 14), color: .white, align: .center))
                }
                Box(.width(.fill(flex: 2)).height(.fix(40)), .color(Color(0.3, 0.3, 0.9))) {
                    Text("2", style: TextStyle(font: Font(size: 14), color: .white, align: .center))
                }
            }

            // Single flex child with 0.5 — should take half the space
            label("flex 0.5")
            Row {
                Box(.width(.fill(flex: 0.5)).height(.fix(40)), .color(Color(0.8, 0.5, 0.2))) {
                    Text("half", style: TextStyle(font: Font(size: 14), color: .white, align: .center))
                }
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
