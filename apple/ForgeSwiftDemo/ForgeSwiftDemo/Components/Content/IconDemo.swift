import ForgeSwift

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
