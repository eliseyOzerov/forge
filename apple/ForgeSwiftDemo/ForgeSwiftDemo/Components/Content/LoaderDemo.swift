import ForgeSwift

struct LoaderDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Loader") {
            DemoSection("Default") {
                Loader()
            }
        }
    }
}
