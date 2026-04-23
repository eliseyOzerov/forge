import ForgeSwift

struct LoaderDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        demoScreen(title: "Loader") {
            demoSection("Default") {
                Loader()
            }
        }
    }
}
