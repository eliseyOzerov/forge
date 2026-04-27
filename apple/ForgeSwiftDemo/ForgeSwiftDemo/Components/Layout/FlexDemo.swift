import ForgeSwift

struct FlexDemo: ModelView {
    func model(context: ViewContext) -> FlexDemoModel { FlexDemoModel(context: context) }
    func builder(model: FlexDemoModel) -> FlexDemoBuilder { FlexDemoBuilder(model: model) }
}

final class FlexDemoModel: ViewModel<FlexDemo> {
    // Axis & layout
    var axis = Binding("horizontal")
    var spacing = Binding(8.0)
    var spread = Binding("none")
    var wrap = Binding(false)
    var crossFill = Binding("sibling")

    // Alignment
    var mainAlign = Binding("start")
    var crossAlign = Binding("start")

    // Children
    var childCount = Binding(3)
    var childMainExtent = Binding("fix")
    var childCrossExtent = Binding("fix")
    var flexWeight = Binding(1.0)
}

final class FlexDemoBuilder: ViewBuilder<FlexDemoModel> {
    override func build(context: ViewContext) -> any View {
        DemoScreen("Flex") {
            // Preview
            DemoSection("Preview") {
                Box(
                    frame: Frame(.fill(), .fix(250)),
                    alignment: .topLeft,
                    surface: .color(Color(0.94, 0.94, 0.96)),
                    shape: .roundedRect(radius: 12)
                ) {
                    buildPreviewFlex()
                }
            }

            // Axis & spread
            DemoSection("Layout") {
                DemoRow("Axis", child: Segmented(value: model.axis, items: ["horizontal", "vertical"]))
                DemoRow("Spread", child: Segmented(value: model.spread, items: ["none", "packed", "between", "around", "even"]))
                DemoRow("Wrap", child: Toggle(value: model.wrap))
                DemoRow("Cross fill", child: Segmented(value: model.crossFill, items: ["sibling", "parent"]))
            }

            // Spacing
            DemoSection("Spacing") {
                DemoRow("Gap", child: Slider(value: model.spacing, range: 0...24))
            }

            // Alignment
            DemoSection("Alignment") {
                DemoRow("Main", child: Segmented(value: model.mainAlign, items: ["start", "center", "end"]))
                DemoRow("Cross", child: Segmented(value: model.crossAlign, items: ["start", "center", "end"]))
            }

            // Children
            DemoSection("Children") {
                DemoRow("Count", child: Stepper(value: model.childCount, range: 0...8, step: 1))
                DemoRow("Main", child: Segmented(value: model.childMainExtent, items: ["fix", "flex"]))
                if model.childMainExtent.value == "flex" {
                    DemoRow("Weight", child: Slider(value: model.flexWeight, range: 1...4))
                }
                DemoRow("Cross", child: Segmented(value: model.childCrossExtent, items: ["fix", "fill"]))
            }
        }
    }

    private func buildPreviewFlex() -> Flex {
        let isH = model.axis.value == "horizontal"
        let axis: Axis = isH ? .horizontal : .vertical

        let spread: Spread? = switch model.spread.value {
        case "packed": .packed
        case "between": .between
        case "around": .around
        case "even": .even
        default: nil
        }

        let mainVal: Double = switch model.mainAlign.value {
        case "start": -1
        case "end": 1
        default: 0
        }
        let crossVal: Double = switch model.crossAlign.value {
        case "start": -1
        case "end": 1
        default: 0
        }
        let alignment = isH
            ? Alignment(mainVal, crossVal)
            : Alignment(crossVal, mainVal)

        let crossFill: CrossFill = model.crossFill.value == "parent" ? .parent : .sibling

        let style = FlexStyle(
            axis: axis,
            spacing: model.spacing.value,
            alignment: alignment,
            spread: spread,
            wrap: model.wrap.value,
            crossFill: crossFill
        )

        let sizes: [(Double, Double)] = [
            (40, 40), (50, 30), (35, 50), (45, 35),
            (40, 45), (55, 30), (30, 40), (50, 50),
        ]
        let colors: [Color] = [
            accent,
            Color(1.0, 0.4, 0.4),
            Color(0.4, 0.8, 0.4),
            Color(1.0, 0.8, 0.2),
            Color(0.8, 0.4, 1.0),
            Color(0.4, 0.8, 0.8),
            Color(1.0, 0.6, 0.3),
            Color(0.6, 0.4, 0.8),
        ]

        let children: [any View] = (0..<model.childCount.value).map { i in
            let (w, h) = sizes[i % sizes.count]

            let mainExtent: Extent = model.childMainExtent.value == "flex"
                ? .flex(i == 0 ? model.flexWeight.value : 1)
                : .fix(isH ? w : h)

            let crossExtent: Extent = model.childCrossExtent.value == "fill"
                ? .fill()
                : .fix(isH ? h : w)

            let frame = isH ? Frame(mainExtent, crossExtent) : Frame(crossExtent, mainExtent)

            return Box(
                frame: frame,
                alignment: .center,
                surface: .color(colors[i % colors.count]),
                shape: .roundedRect(radius: 6)
            ) {
                Text("\(i + 1)", style: TextStyle(font: Font(size: 13, weight: 600), color: .white))
            } as any View
        }

        return Flex(style, children: children)
    }
}
