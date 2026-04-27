import ForgeSwift

struct BoxDemo: ModelView {
    func model(context: ViewContext) -> BoxDemoModel { BoxDemoModel(context: context) }
    func builder(model: BoxDemoModel) -> BoxDemoBuilder { BoxDemoBuilder(model: model) }
}

final class BoxDemoModel: ViewModel<BoxDemo> {
    // Frame
    var widthMode = Binding("fix")
    var heightMode = Binding("fix")
    var fixedWidth = Binding(120.0)
    var fixedHeight = Binding(120.0)

    // Padding
    var paddingAll = Binding(0.0)

    // Alignment
    var alignment = Binding("center")

    // Surface
    var showSurface = Binding(true)
    var cornerRadius = Binding(12.0)

    // Children
    var childCount = Binding(1)
}

final class BoxDemoBuilder: ViewBuilder<BoxDemoModel> {
    override func build(context: ViewContext) -> any View {
        DemoScreen("Box") {
            // Preview
            DemoSection("Preview") {
                Box(
                    frame: .fill(.horizontal).height(.fix(200)),
                    alignment: .center,
                    surface: .color(Color(0.94, 0.94, 0.96)),
                    shape: .roundedRect(radius: 12)
                ) {
                    buildPreviewBox()
                }
            }

            // Frame
            DemoSection("Frame") {
                DemoRow("Width", child: Segmented(value: model.widthMode, items: ["fit", "fix", "fill"]))
                if model.widthMode.value == "fix" {
                    DemoRow("Width", child: Slider(value: model.fixedWidth, range: 20...200))
                }
                DemoRow("Height", child: Segmented(value: model.heightMode, items: ["fit", "fix", "fill"]))
                if model.heightMode.value == "fix" {
                    DemoRow("Height", child: Slider(value: model.fixedHeight, range: 20...200))
                }
            }

            // Padding
            DemoSection("Padding") {
                DemoRow("All", child: Slider(value: model.paddingAll, range: 0...40))
            }

            // Alignment
            DemoSection("Alignment") {
                DemoRow("Position", child: Segmented(value: model.alignment, items: ["topLeft", "center", "bottomRight"]))
            }

            // Surface
            DemoSection("Surface") {
                DemoRow("Show", child: Toggle(value: model.showSurface))
                if model.showSurface.value {
                    DemoRow("Radius", child: Slider(value: model.cornerRadius, range: 0...40))
                }
            }

            // Children
            DemoSection("Children") {
                DemoRow("Count", child: Stepper(value: model.childCount, range: 0...5, step: 1))
            }
        }
    }

    private func buildPreviewBox() -> Box {
        let width: Extent = switch model.widthMode.value {
        case "fit": .fit()
        case "fill": .fill()
        default: .fix(model.fixedWidth.value)
        }
        let height: Extent = switch model.heightMode.value {
        case "fit": .fit()
        case "fill": .fill()
        default: .fix(model.fixedHeight.value)
        }
        let alignment: Alignment = switch model.alignment.value {
        case "topLeft": .topLeft
        case "bottomRight": .bottomRight
        default: .center
        }
        let surface: Surface? = model.showSurface.value
            ? .color(accent).shadow(color: Color(0.25, 0.48, 1.0, 0.3), offset: Vec2(0, 2), blur: 8)
            : nil
        let shape: AnyShape? = model.showSurface.value
            ? .roundedRect(radius: model.cornerRadius.value)
            : nil

        let children: [any View] = (0..<model.childCount.value).map { i in
            let colors: [Color] = [
                Color(1.0, 0.4, 0.4),
                Color(0.4, 0.8, 0.4),
                Color(0.4, 0.4, 1.0),
                Color(1.0, 0.8, 0.2),
                Color(0.8, 0.4, 1.0),
            ]
            return Box(
                frame: .fixed(30, 30),
                surface: .color(colors[i % colors.count]),
                shape: .roundedRect(radius: 6)
            ) as any View
        }

        return Box(
            frame: Frame(width, height),
            padding: .all(model.paddingAll.value),
            alignment: alignment,
            surface: surface,
            shape: shape,
            children: children
        )
    }
}
