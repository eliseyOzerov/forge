import ForgeSwift

// MARK: - Design Tokens

let bg = Color(0.96, 0.96, 0.97)
let cardBg = Color.white
let accent = Color(0.25, 0.48, 1.0)
let subtitle = Color(0.45, 0.45, 0.5)
let sectionTitle = TextStyle(font: Font(size: 13, weight: 600), color: subtitle, textCase: .uppercase)
let cardTitle = TextStyle(font: Font(size: 15, weight: 600), color: Color(0.1, 0.1, 0.12))
let cardRadius: Double = 14
let cardShadow = Surface.shadow(color: Color(0, 0, 0, 0.06), offset: Vec2(0, 2), blur: 6)

// MARK: - Demo Views

/// Scrollable detail screen with a title in the navigation bar.
struct DemoScreen: BuiltView {
    let title: String
    let children: [any View]

    init(_ title: String, @ChildrenBuilder content: () -> [any View]) {
        self.title = title
        self.children = content()
    }

    func build(context: ViewContext) -> any View {
        Scroll(.vertical) {
            Column(spacing: 24, alignment: .topLeft, children: children)
                .padded(Padding(top: 16, bottom: 40, leading: 20, trailing: 20))
        }
        .navigation(title: title)
        .framed(.fill)
        .style { s in s.copy { $0.surface = .color(bg) } }
    }
}

/// Labeled group within a demo screen.
struct DemoSection: BuiltView {
    let title: String
    let children: [any View]

    init(_ title: String, @ChildrenBuilder content: () -> [any View]) {
        self.title = title
        self.children = content()
    }

    func build(context: ViewContext) -> any View {
        Column(spacing: 10, alignment: .topLeft) {
            Text(title, style: TextStyle(font: Font(size: 13, weight: 600), color: subtitle, textCase: .uppercase))
            Column(spacing: 8, alignment: .topLeft, children: children)
        }
    }
}

/// Label + control row within a demo section.
struct DemoRow: BuiltView {
    let label: String
    let child: any View

    init(_ label: String, child: any View) {
        self.label = label
        self.child = child
    }

    func build(context: ViewContext) -> any View {
        Row(spacing: 0, alignment: .center, spread: .between) {
            Text(label, style: TextStyle(font: Font(size: 14, weight: 500), color: Color(0.3, 0.3, 0.35)))
            child
        }
        .framed(.fillWidth)
    }
}
