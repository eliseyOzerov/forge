import UIKit
import ForgeSwift

@main
class ForgeDemo: App {
    override var body: any View {
        Router { CatalogScreen() }
    }
}

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
                    Box(frame: .fixed(48, 48), alignment: .center, surface: .color(Color(0.94, 0.94, 0.96)), shape: .roundedRect(radius: 10)) {
                        preview
                    }
                    Text(title, style: cardTitle)
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
