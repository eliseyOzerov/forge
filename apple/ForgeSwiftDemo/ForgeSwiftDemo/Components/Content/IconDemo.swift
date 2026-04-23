import ForgeSwift

struct IconDemo: BuiltView {
    func build(context: ViewContext) -> any View {
        DemoScreen( "Icon & Symbol") {
            DemoSection("Symbols") {
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
