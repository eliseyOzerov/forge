import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Row {
            Box(frame: .flex(.h).fill(.v), surface: .color(.blue))
            Text("Hello World!").framed(.fix(.v, 30))
            Box(frame: .flex(.h).fill(.v), surface: .color(.red))
        }
        .centered()
    }
}

// MARK: - Catalog Screen

struct CatalogScreen: BuiltView {
    func build(context: ViewContext) -> any View {
        Scrollable(.vertical) {
            Column(spacing: 28, alignment: .topLeft) {
                Text("Forge", style: TextStyle(font: Font(size: 32, weight: 800), color: Color(0.1, 0.1, 0.12)))
                
                ListItem(
                    title: "Hello World!",
                    subtitle: "This is a list item",
                    trailing: Symbol("chevron.right")
                )

                CatalogSection("Layout") {
                    CatalogCard("Box", preview: BoxPreview()) { BoxDemo() }
                    CatalogCard("Flex", preview: FlexPreview()) { FlexDemo() }
                }

                CatalogSection("Content") {
                    CatalogCard("Text", preview: TextPreview()) { TextDemo() }
                    CatalogCard("Icon", preview: IconPreview()) { IconDemo() }
                    CatalogCard("Loader", preview: LoaderPreview()) { LoaderDemo() }
                }

                CatalogSection("Input") {
                    CatalogCard("Button", preview: ButtonPreview()) { ButtonDemo() }
                    CatalogCard("Toggle", preview: TogglePreview()) { ToggleDemo() }
                    CatalogCard("Slider", preview: SliderPreview()) { SliderDemo() }
                    CatalogCard("Stepper", preview: StepperPreview()) { StepperDemo() }
                    CatalogCard("Segmented", preview: SegmentedPreview()) { SegmentedDemo() }
                    CatalogCard("TextField", preview: TextFieldPreview()) { TextFieldDemo() }
                }
            }
            .padded(Padding(top: 16, bottom: 40, leading: 20, trailing: 20))
        }
    }
}

// MARK: - Catalog Components

struct CatalogSection: BuiltView {
    let title: String
    let children: [any View]

    init(_ title: String, @ChildrenBuilder content: () -> [any View]) {
        self.title = title
        self.children = content()
    }

    func build(context: ViewContext) -> any View {
        Column {
            Text(title, style: sectionTitle)
                .padded(.leading(4))
            Column(children: children)
        }
    }
}

struct CatalogCard: BuiltView {
    let title: String
    let preview: any View
    let screen: @MainActor () -> any View

    init(_ title: String, preview: any View, screen: @escaping @MainActor () -> any View) {
        self.title = title
        self.preview = preview
        self.screen = screen
    }

    func build(context: ViewContext) -> any View {
        let router = context.router
        return Button(onTap: { router.push(Screen { screen() }) }) {
            Box(
                frame: .fill(.horizontal),
                padding: Padding(top: 16, bottom: 12, leading: 16, trailing: 16),
                alignment: .topLeft,
                surface: cardShadow.color(cardBg),
                shape: .roundedRect(radius: cardRadius)
            ) {
                ListItem(
                    leading: Box(
                        frame: .fixed(48, 48),
                        alignment: .center,
                        surface: .color(Color(0.94, 0.94, 0.96)),
                        shape: .roundedRect(radius: 10)
                    ) { preview },
                    primary: Text(title, style: cardTitle),
                    trailing: Text("›", style: TextStyle(font: Font(size: 22, weight: 300), color: Color(0.75, 0.75, 0.78))),
                    style: ListItemStyle(padding: .zero)
                )
            }
        }
    }
}

// MARK: - Card Previews

struct TextPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Text("Aa", style: TextStyle(font: Font(size: 20, weight: 700), color: accent))
    }
}

struct IconPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Text("◆", style: TextStyle(font: Font(size: 20, weight: 400), color: accent))
    }
}

struct LoaderPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Loader()
    }
}

struct ButtonPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Box(frame: .fixed(32, 20), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 6)) {
            Text("Tap", style: TextStyle(font: Font(size: 9, weight: 600), color: .white))
        }
    }
}

struct TogglePreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Box(frame: .fixed(28, 16), surface: .color(accent), shape: .roundedRect(radius: 8)) {
            Box(frame: .fixed(12, 12), alignment: .centerRight, surface: .color(.white), shape: CircleShape().erased)
        }
    }
}

struct SliderPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Row(alignment: .center) {
            Box(frame: .fixed(20, 3), surface: .color(accent), shape: .roundedRect(radius: 1.5))
            Box(frame: .fixed(8, 8), surface: .color(accent), shape: CircleShape().erased)
            Box(frame: .fixed(12, 3), surface: .color(Color(0.82, 0.82, 0.84)), shape: .roundedRect(radius: 1.5))
        }
    }
}

struct StepperPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Row(spacing: 4, alignment: .center) {
            Text("−", style: TextStyle(font: Font(size: 14, weight: 600), color: accent))
            Text("3", style: TextStyle(font: Font(size: 14, weight: 700), color: Color(0.1, 0.1, 0.12)))
            Text("+", style: TextStyle(font: Font(size: 14, weight: 600), color: accent))
        }
    }
}

struct SegmentedPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Row(spacing: 2) {
            Box(frame: .fixed(16, 14), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 4)) {
                Text("A", style: TextStyle(font: Font(size: 8, weight: 600), color: .white))
            }
            Box(frame: .fixed(16, 14), alignment: .center, shape: .roundedRect(radius: 4)) {
                Text("B", style: TextStyle(font: Font(size: 8, weight: 500), color: subtitle))
            }
        }
    }
}

struct TextFieldPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Box(frame: .fixed(32, 18), alignment: .centerLeft, surface: .color(.white).border(Color(0.82, 0.82, 0.84), width: 1), shape: .roundedRect(radius: 4)) {
            Text("...", style: TextStyle(font: Font(size: 10, weight: 400), color: subtitle))
                .padded(Padding(leading: 4))
        }
    }
}

struct BoxPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Box(frame: .fixed(24, 24), surface: .color(accent).shadow(color: Color(0.25, 0.48, 1.0, 0.3), offset: Vec2(0, 2), blur: 4), shape: .roundedRect(radius: 6))
    }
}

struct FlexPreview: BuiltView {
    func build(context: ViewContext) -> any View {
        Column(spacing: 2) {
            Row(spacing: 2) {
                Box(frame: .fixed(12, 8), surface: .color(accent), shape: .roundedRect(radius: 2))
                Box(frame: .fixed(18, 8), surface: .color(accent.withAlpha(0.6)), shape: .roundedRect(radius: 2))
            }
            Row(spacing: 2) {
                Box(frame: .fixed(8, 8), surface: .color(accent.withAlpha(0.4)), shape: .roundedRect(radius: 2))
                Box(frame: .fixed(12, 8), surface: .color(accent.withAlpha(0.7)), shape: .roundedRect(radius: 2))
                Box(frame: .fixed(8, 8), surface: .color(accent.withAlpha(0.5)), shape: .roundedRect(radius: 2))
            }
        }
    }
}
