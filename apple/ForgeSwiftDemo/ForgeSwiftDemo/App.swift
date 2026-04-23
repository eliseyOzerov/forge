import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Router { CatalogScreen() }
    }
}

// MARK: - Design Tokens

private let bg = Color(0.96, 0.96, 0.97)
private let cardBg = Color.white
private let accent = Color(0.25, 0.48, 1.0)
private let subtitle = Color(0.45, 0.45, 0.5)
private let sectionTitle = TextStyle(font: Font(size: 13, weight: 600), color: subtitle, textCase: .uppercase)
private let cardTitle = TextStyle(font: Font(size: 15, weight: 600), color: Color(0.1, 0.1, 0.12))
private let cardRadius: Double = 14
private let cardShadow = Surface.shadow(color: Color(0, 0, 0, 0.06), offset: Vec2(0, 2), blur: 6)

// MARK: - Catalog Screen

struct CatalogScreen: BuiltView {
    func build(context: ViewContext) -> any View {
        let router = context.router

        return Scroll(.vertical) {
            Column(spacing: 28, alignment: .topLeft) {
                // Header
                Text("Forge", style: TextStyle(font: Font(size: 32, weight: 800), color: Color(0.1, 0.1, 0.12)))
                Text("Component Catalog", style: TextStyle(font: Font(size: 15, weight: 500), color: subtitle))

                // Content
                section("Content") {
                    catalogCard("Text", preview: textPreview(), router: router) { TextDemo() }
                    catalogCard("Icon", preview: iconPreview(), router: router) { IconDemo() }
                    catalogCard("Loader", preview: loaderPreview(), router: router) { LoaderDemo() }
                }

                // Input
                section("Input") {
                    catalogCard("Button", preview: buttonPreview(), router: router) { ButtonDemo() }
                    catalogCard("Toggle", preview: togglePreview(), router: router) { ToggleDemo() }
                    catalogCard("Slider", preview: sliderPreview(), router: router) { SliderDemo() }
                    catalogCard("Stepper", preview: stepperPreview(), router: router) { StepperDemo() }
                    catalogCard("Segmented", preview: segmentedPreview(), router: router) { SegmentedDemo() }
                    catalogCard("TextField", preview: textFieldPreview(), router: router) { TextFieldDemo() }
                }

                // Layout
                section("Layout") {
                    catalogCard("Box", preview: boxPreview(), router: router) { BoxDemo() }
                    catalogCard("Flex", preview: flexPreview(), router: router) { FlexDemo() }
                }
            }
            .padded(Padding(top: 16, bottom: 40, leading: 20, trailing: 20))
        }
        .navigation(title: nil, hidden: true)
        .framed(.fill)
        .style { s in s.copy { $0.surface = .color(bg) } }
    }

    // MARK: - Section

    private func section(_ title: String, @ChildrenBuilder content: () -> [any View]) -> some View {
        Column(spacing: 12, alignment: .topLeft) {
            Text(title, style: sectionTitle)
                .padded(Padding(leading: 4))
            Column(spacing: 10, alignment: .topLeft, content: content)
        }
    }

    // MARK: - Card

    private func catalogCard(_ title: String, preview: any View, router: any RouterHandle, screen: @escaping @MainActor () -> any View) -> some View {
        Button(onTap: { router.push(Screen { screen() }) }) {
            Box(frame: .fillWidth, padding: Padding(top: 16, bottom: 12, leading: 16, trailing: 16), alignment: .topLeft, surface: cardShadow.color(cardBg), shape: .roundedRect(radius: cardRadius)) {
                Row(spacing: 12, alignment: .center) {
                    // Preview area
                    Box(frame: .fixed(48, 48), alignment: .center, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10)) {
                        preview
                    }

                    // Title
                    Text(title, style: cardTitle)

                    // Spacer + chevron
                    Box(frame: .fillWidth)
                    Text("›", style: TextStyle(font: Font(size: 22, weight: 300), color: Color(0.75, 0.75, 0.78)))
                }
            }
        }
    }

    // MARK: - Previews

    private func textPreview() -> any View {
        Text("Aa", style: TextStyle(font: Font(size: 20, weight: 700), color: accent))
    }

    private func iconPreview() -> any View {
        Text("◆", style: TextStyle(font: Font(size: 20, weight: 400), color: accent))
    }

    private func loaderPreview() -> any View {
        Loader()
    }

    private func buttonPreview() -> any View {
        Box(frame: .fixed(32, 20), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 6)) {
            Text("Tap", style: TextStyle(font: Font(size: 9, weight: 600), color: .white))
        }
    }

    private func togglePreview() -> any View {
        Box(frame: .fixed(28, 16), surface: .color(accent), shape: .roundedRect(radius: 8)) {
            Box(frame: .fixed(12, 12), alignment: .centerRight, surface: .color(.white), shape: CircleShape().erased)
        }
    }

    private func sliderPreview() -> any View {
        Row(alignment: .center) {
            Box(frame: .fixed(20, 3), surface: .color(accent), shape: .roundedRect(radius: 1.5))
            Box(frame: .fixed(8, 8), surface: .color(accent), shape: CircleShape().erased)
            Box(frame: .fixed(12, 3), surface: .color(Color(0.82, 0.82, 0.84)), shape: .roundedRect(radius: 1.5))
        }
    }

    private func stepperPreview() -> any View {
        Row(spacing: 4, alignment: .center) {
            Text("−", style: TextStyle(font: Font(size: 14, weight: 600), color: accent))
            Text("3", style: TextStyle(font: Font(size: 14, weight: 700), color: Color(0.1, 0.1, 0.12)))
            Text("+", style: TextStyle(font: Font(size: 14, weight: 600), color: accent))
        }
    }

    private func segmentedPreview() -> any View {
        Row(spacing: 2) {
            Box(frame: .fixed(16, 14), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 4)) {
                Text("A", style: TextStyle(font: Font(size: 8, weight: 600), color: .white))
            }
            Box(frame: .fixed(16, 14), alignment: .center, shape: .roundedRect(radius: 4)) {
                Text("B", style: TextStyle(font: Font(size: 8, weight: 500), color: subtitle))
            }
        }
    }

    private func textFieldPreview() -> any View {
        Box(frame: .fixed(32, 18), alignment: .centerLeft, surface: .color(.white).border(Color(0.82, 0.82, 0.84), width: 1), shape: .roundedRect(radius: 4)) {
            Text("...", style: TextStyle(font: Font(size: 10, weight: 400), color: subtitle))
                .padded(Padding(leading: 4))
        }
    }

    private func boxPreview() -> any View {
        Box(frame: .fixed(24, 24), surface: .color(accent).shadow(color: Color(0.25, 0.48, 1.0, 0.3), offset: Vec2(0, 2), blur: 4), shape: .roundedRect(radius: 6))
    }

    private func flexPreview() -> any View {
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

// MARK: - Demo Screen Template

private func demoScreen(title: String, @ChildrenBuilder content: () -> [any View]) -> any View {
    Scroll(.vertical) {
        Column(spacing: 24, alignment: .topLeft, content: content)
            .padded(Padding(top: 16, bottom: 40, leading: 20, trailing: 20))
    }
    .navigation(title: title)
    .framed(.fill)
    .style { s in s.copy { $0.surface = .color(bg) } }
}

private func demoSection(_ title: String, @ChildrenBuilder content: () -> [any View]) -> any View {
    Column(spacing: 10, alignment: .topLeft) {
        Text(title, style: TextStyle(font: Font(size: 13, weight: 600), color: subtitle, textCase: .uppercase))
        Column(spacing: 8, alignment: .topLeft, content: content)
    }
}

private func demoRow(_ label: String, child: any View) -> any View {
    Row(spacing: 0, alignment: .center, spread: .between) {
        Text(label, style: TextStyle(font: Font(size: 14, weight: 500), color: Color(0.3, 0.3, 0.35)))
        child
    }
    .framed(.fillWidth)
}

// MARK: - Text Demo

struct TextDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Text") {
            demoSection("Sizes") {
                Text("Title", style: TextStyle(font: Font(size: 28, weight: 800)))
                Text("Headline", style: TextStyle(font: Font(size: 20, weight: 700)))
                Text("Body text in regular weight", style: TextStyle(font: Font(size: 16, weight: 400)))
                Text("Caption — small and light", style: TextStyle(font: Font(size: 12, weight: 400), color: subtitle))
            }
            demoSection("Color") {
                Text("Default", style: TextStyle(font: Font(size: 16)))
                Text("Accent", style: TextStyle(font: Font(size: 16, weight: 600), color: accent))
                Text("Subtle", style: TextStyle(font: Font(size: 16), color: subtitle))
                Text("Danger", style: TextStyle(font: Font(size: 16, weight: 600), color: Color(0.9, 0.25, 0.25)))
            }
            demoSection("Alignment") {
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
            demoSection("Overflow") {
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

// MARK: - Icon Demo

struct IconDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Icon & Symbol") {
            demoSection("Symbols") {
                Row(spacing: 16, alignment: .center) {
                    Symbol("star.fill")
                    Symbol("heart.fill")
                    Symbol("bell.fill")
                    Symbol("gear")
                    Symbol("magnifyingglass")
                }
            }
        }
    }
}

// MARK: - Loader Demo

struct LoaderDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Loader") {
            demoSection("Default") {
                Loader()
            }
        }
    }
}

// MARK: - Button Demo

struct ButtonDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Button") {
            demoSection("Styles") {
                Button("Primary") {}
                Button("Secondary") {}
                Button("Disabled") {}
            }
        }
    }
}

// MARK: - Toggle Demo

struct ToggleDemo: ModelView {
    func model(context: ViewContext) -> ToggleDemoModel { ToggleDemoModel(context: context) }
    func builder(model: ToggleDemoModel) -> ToggleDemoBuilder { ToggleDemoBuilder(model: model) }
}

final class ToggleDemoModel: ViewModel<ToggleDemo> {
    var switchValue = Binding(true)
    var checkValue = Binding(false)
}

final class ToggleDemoBuilder: ViewBuilder<ToggleDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "Toggle") {
            demoSection("Switch") {
                demoRow("Enabled", child: Toggle(value: model.switchValue, style: .constant(ToggleStyle(painter: SwitchPainter()))))
            }
            demoSection("Checkbox") {
                demoRow("Checked", child: Toggle(value: model.checkValue))
            }
        }
    }
}

// MARK: - Slider Demo

struct SliderDemo: ModelView {
    func model(context: ViewContext) -> SliderDemoModel { SliderDemoModel(context: context) }
    func builder(model: SliderDemoModel) -> SliderDemoBuilder { SliderDemoBuilder(model: model) }
}

final class SliderDemoModel: ViewModel<SliderDemo> {
    var value = Binding(0.5)
}

final class SliderDemoBuilder: ViewBuilder<SliderDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "Slider") {
            demoSection("Basic") {
                Slider(value: model.value)
            }
        }
    }
}

// MARK: - Stepper Demo

struct StepperDemo: ModelView {
    func model(context: ViewContext) -> StepperDemoModel { StepperDemoModel(context: context) }
    func builder(model: StepperDemoModel) -> StepperDemoBuilder { StepperDemoBuilder(model: model) }
}

final class StepperDemoModel: ViewModel<StepperDemo> {
    var count = Binding(0)
}

final class StepperDemoBuilder: ViewBuilder<StepperDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "Stepper") {
            demoSection("Integer") {
                Stepper(value: model.count, range: 0...100, step: 1)
            }
        }
    }
}

// MARK: - Segmented Demo

struct SegmentedDemo: ModelView {
    func model(context: ViewContext) -> SegmentedDemoModel { SegmentedDemoModel(context: context) }
    func builder(model: SegmentedDemoModel) -> SegmentedDemoBuilder { SegmentedDemoBuilder(model: model) }
}

final class SegmentedDemoModel: ViewModel<SegmentedDemo> {
    var selected = Binding("One")
}

final class SegmentedDemoBuilder: ViewBuilder<SegmentedDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "Segmented") {
            demoSection("Basic") {
                Segmented(value: model.selected, items: ["One", "Two", "Three"])
            }
        }
    }
}

// MARK: - TextField Demo

struct TextFieldDemo: ModelView {
    func model(context: ViewContext) -> TextFieldDemoModel { TextFieldDemoModel(context: context) }
    func builder(model: TextFieldDemoModel) -> TextFieldDemoBuilder { TextFieldDemoBuilder(model: model) }
}

final class TextFieldDemoModel: ViewModel<TextFieldDemo> {
    var text = Binding("")
    var email = Binding("")
}

final class TextFieldDemoBuilder: ViewBuilder<TextFieldDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "TextField") {
            demoSection("Basic") {
                TextField(text: model.text, decoration: TextFieldDecoration(placeholder: "Type something..."))
            }
            demoSection("With label") {
                TextField(text: model.email, decoration: TextFieldDecoration(placeholder: "you@example.com", label: "Email"))
            }
        }
    }
}

// MARK: - Box Demo

struct BoxDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Box") {
            demoSection("Frame modes") {
                Row(spacing: 8, alignment: .center) {
                    Box(frame: .fixed(60, 60), alignment: .center, surface: .color(accent), shape: .roundedRect(radius: 10)) {
                        Text("Fix", style: TextStyle(font: Font(size: 11, weight: 600), color: .white))
                    }
                    Box(frame: .fixed(80, 60), alignment: .center, surface: .color(accent.withAlpha(0.7)), shape: .roundedRect(radius: 10)) {
                        Text("Hug", style: TextStyle(font: Font(size: 11, weight: 600), color: .white))
                    }
                }
            }
            demoSection("Shapes") {
                Row(spacing: 12, alignment: .center) {
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: .roundedRect(radius: 8))
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: .roundedRect(radius: 25))
                    Box(frame: .fixed(50, 50), surface: .color(accent), shape: CircleShape().erased)
                }
            }
            demoSection("Surface") {
                Row(spacing: 12, alignment: .center) {
                    Box(frame: .fixed(60, 60), surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10))
                    Box(frame: .fixed(60, 60), surface: .color(.white).border(accent, width: 2), shape: .roundedRect(radius: 10))
                    Box(frame: .fixed(60, 60), surface: .color(.white).shadow(color: Color(0, 0, 0, 0.15), offset: Vec2(0, 4), blur: 12), shape: .roundedRect(radius: 10))
                }
            }
            demoSection("Padding & Alignment") {
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

// MARK: - Flex Demo

struct FlexDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Flex") {
            demoSection("Row — packed") {
                Row(spacing: 8, alignment: .center) {
                    chip("A"); chip("B"); chip("C")
                }
            }
            demoSection("Row — between") {
                Row(spread: .between) {
                    chip("1"); chip("2"); chip("3")
                }
                .framed(.fillWidth)
            }
            demoSection("Row — around") {
                Row(spread: .around) {
                    chip("X"); chip("Y"); chip("Z")
                }
                .framed(.fillWidth)
            }
            demoSection("Row — even") {
                Row(spread: .even) {
                    chip("!"); chip("@"); chip("#")
                }
                .framed(.fillWidth)
            }
            demoSection("Column") {
                Column(spacing: 6, alignment: .topLeft) {
                    chip("Top")
                    chip("Middle")
                    chip("Bottom")
                }
            }
            demoSection("Flex children") {
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
            demoSection("Wrap") {
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
