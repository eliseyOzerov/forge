import ForgeSwift

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
