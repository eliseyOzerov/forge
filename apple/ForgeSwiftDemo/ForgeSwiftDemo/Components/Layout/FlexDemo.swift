import ForgeSwift

struct FlexDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Flex") {
            DemoSection("Row — packed") {
                Row(spacing: 8, alignment: .center) {
                    chip("A"); chip("B"); chip("C")
                }
            }
            DemoSection("Row — between") {
                Row(spread: .between) {
                    chip("1"); chip("2"); chip("3")
                }
                .framed(.fillWidth)
            }
            DemoSection("Row — around") {
                Row(spread: .around) {
                    chip("X"); chip("Y"); chip("Z")
                }
                .framed(.fillWidth)
            }
            DemoSection("Row — even") {
                Row(spread: .even) {
                    chip("!"); chip("@"); chip("#")
                }
                .framed(.fillWidth)
            }
            DemoSection("Column") {
                Column(spacing: 6, alignment: .topLeft) {
                    chip("Top")
                    chip("Middle")
                    chip("Bottom")
                }
            }
            DemoSection("Flex children") {
                Row(spacing: 8) {
                    chip("fix")
                    Box(frame: .fixed(0, 36), alignment: .center, surface: .color(accent.withAlpha(0.3)), shape: .roundedRect(radius: 8)) {
                        Text("flex", style: TextStyle(font: Font(size: 12, weight: 500), color: accent))
                    }
                    .flex()
                    chip("fix")
                }
                .framed(.fillWidth)
            }
            DemoSection("Wrap") {
                Row(spacing: 6, wrap: true) {
                    for t in ["Swift", "Forge", "UI", "Layout", "Flex", "Wrap", "Demo"] {
                        tag(t)
                    }
                }
                .framed(.fillWidth)
            }
        }
    }

    private func chip(_ text: String) -> Box {
        Box(frame: .fixed(36, 36), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 8)) {
            Text(text, style: TextStyle(font: Font(size: 13, weight: 600), color: .white))
        }
    }

    private func tag(_ text: String) -> Box {
        Box(padding: Padding(top: 6, bottom: 6, leading: 12, trailing: 12), surface: .color(accent.withAlpha(0.12)), shape: .roundedRect(radius: 14)) {
            Text(text, style: TextStyle(font: Font(size: 13, weight: 500), color: accent))
        }
    }
}
