import ForgeSwift

struct ButtonDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Button") {
            DemoSection("Styles") {
                Button("Primary") {}
                Button("Secondary") {}
                Button("Disabled") {}
            }
        }
    }
}
