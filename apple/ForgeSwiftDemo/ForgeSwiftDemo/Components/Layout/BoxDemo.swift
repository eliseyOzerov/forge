import ForgeSwift

struct BoxDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Box") {
            DemoSection("Frame modes") {
                Row(spacing: 8, alignment: .center) {
                    Box(frame: .fixed(60, 60), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 10)) {
                        Text("Fix", style: TextStyle(font: Font(size: 11, weight: 600), color: .white))
                    }
                    Box(frame: .fixed(80, 60), alignment: .center, surface: .color(accent.withAlpha(0.7)), shape: .roundedRect(radius: 10)) {
                        Text("Hug", style: TextStyle(font: Font(size: 11, weight: 600), color: .white))
                    }
                }
            }
            DemoSection("Shapes") {
                Row(spacing: 12, alignment: .center) {
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: .roundedRect(radius: 8))
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: .roundedRect(radius: 25))
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: CircleShape().erased)
                }
            }
            DemoSection("Surface") {
                Row(spacing: 12, alignment: .center) {
                    Box(frame: .fixed(60, 60), surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10))
                    Box(frame: .fixed(60, 60), surface: .color(.white).border(accent, width: 2), shape: .roundedRect(radius: 10))
                    Box(frame: .fixed(60, 60), surface: .color(.white).shadow(color: Color(0, 0, 0, 0.15), offset: Vec2(0, 4), blur: 12), shape: .roundedRect(radius: 10))
                }
            }
            DemoSection("Padding & Alignment") {
                Box(frame: .fixed(200, 100), alignment: .topLeft, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10)) {
                    Box(frame: .fixed(40, 40), surface: .color(accent), shape: .roundedRect(radius: 6))
                }
                Box(frame: .fixed(200, 100), alignment: .bottomRight, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10)) {
                    Box(frame: .fixed(40, 40), surface: .color(accent), shape: .roundedRect(radius: 6))
                }
            }
        }
    }
}
