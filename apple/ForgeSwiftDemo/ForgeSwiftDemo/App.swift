//
//  App.swift
//  ForgeSwiftDemo
//

import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        TextFieldDemo()
    }
}

// MARK: - TextField Demo

struct TextFieldDemo: ModelView {
    func makeModel(context: BuildContext) -> TextFieldDemoModel { TextFieldDemoModel() }
    func makeBuilder() -> TextFieldDemoBuilder { TextFieldDemoBuilder() }
}

final class TextFieldDemoModel: ViewModel<TextFieldDemo> {
    var text = ""
    var otp = ""
    var tags: [String] = ["swift", "forge"]
    var card = CreditCard()
}

final class TextFieldDemoBuilder: ViewBuilder<TextFieldDemoModel> {
    public override func build(context: BuildContext) -> any View {
//        Box(.fill) {
//            Column(spacing: 24, alignment: .topLeft) {
//                Text("Input Demo", style: TextStyle(font: Font(size: 24, weight: 700)))
//
//                // Basic text field
//                TextField<String>(text: bind(\.text),
//                    decoration: TextFieldDecoration(placeholder: "Type something...", label: "Text"))
//
//                // OTP / PIN
//                Text("OTP Code", style: TextStyle(font: Font(size: 14, weight: 500)))
//                SplitBoxInput(text: bind(\.otp), length: 6)
//
//                // Token input
//                Text("Tags", style: TextStyle(font: Font(size: 14, weight: 500)))
//                TokenInput(values: bind(\.tags))
//
//                // Credit card
//                Text("Payment", style: TextStyle(font: Font(size: 14, weight: 500)))
//                CreditCardInput(value: bind(\.card))
//
//            }.padded(20)
//        }
        Box(.fill, alignment: .center) {
            TextField<String>(text: bind(\.text),
                decoration: TextFieldDecoration(placeholder: "Type something...", label: "Text"))
        }
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
