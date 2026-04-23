import ForgeSwift

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
