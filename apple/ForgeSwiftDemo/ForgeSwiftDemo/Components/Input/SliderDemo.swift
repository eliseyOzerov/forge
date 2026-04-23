import ForgeSwift

struct SliderDemo: ModelView {
    func model(context: ViewContext) -> SliderDemoModel { SliderDemoModel(context: context) }
    func builder(model: SliderDemoModel) -> SliderDemoBuilder { SliderDemoBuilder(model: model) }
}

final class SliderDemoModel: ViewModel<SliderDemo> {
    var value = Binding(0.5)
}

final class SliderDemoBuilder: ViewBuilder<SliderDemoModel> {
    override func build(context: ViewContext) -> any View {
        DemoScreen( "Slider") {
            DemoSection("Basic") {
                Slider(value: model.value)
            }
        }
    }
}
