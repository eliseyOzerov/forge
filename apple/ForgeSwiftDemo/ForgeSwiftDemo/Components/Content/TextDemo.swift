import ForgeSwift

struct TextDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Text") {
            DemoSection("Sizes") {
                Text("Title", style: TextStyle(font: Font(size: 28, weight: 800)))
                Text("Headline", style: TextStyle(font: Font(size: 20, weight: 700)))
                Text("Body text in regular weight", style: TextStyle(font: Font(size: 16, weight: 400)))
                Text("Caption — small and light", style: TextStyle(font: Font(size: 12, weight: 400), color: subtitle))
            }
            DemoSection("Color") {
                Text("Default", style: TextStyle(font: Font(size: 16)))
                Text("Accent", style: TextStyle(font: Font(size: 16, weight: 600), color: accent))
                Text("Subtle", style: TextStyle(font: Font(size: 16), color: subtitle))
                Text("Danger", style: TextStyle(font: Font(size: 16, weight: 600), color: Color(0.9, 0.25, 0.25)))
            }
            DemoSection("Alignment") {
                Box(frame: .fillWidth, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 8)) {
                    Text("Leading", style: TextStyle(font: Font(size: 14), align: .leading))
                }
                .framed(.fillWidth)
                Box(frame: .fillWidth, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 8)) {
                    Text("Center", style: TextStyle(font: Font(size: 14), align: .center))
                }
                .framed(.fillWidth)
                Box(frame: .fillWidth, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 8)) {
                    Text("Trailing", style: TextStyle(font: Font(size: 14), align: .trailing))
                }
                .framed(.fillWidth)
            }
            DemoSection("Overflow") {
                Box(frame: .fixed(200, 40), surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 8).erased, clip: true) {
                    Text("This is a long text that should be truncated when it exceeds the available space in the container", style: TextStyle(font: Font(size: 14), maxLines: 1, overflow: .ellipsis))
                        .padded(Padding(leading: 8, trailing: 8))
                }
                Box(frame: .fixed(200, 60), surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 8).erased, clip: true) {
                    Text("Two lines max. This text wraps but truncates after the second line to keep things compact.", style: TextStyle(font: Font(size: 14), maxLines: 2, overflow: .ellipsis))
                        .padded(8)
                }
            }
        }
    }
}
