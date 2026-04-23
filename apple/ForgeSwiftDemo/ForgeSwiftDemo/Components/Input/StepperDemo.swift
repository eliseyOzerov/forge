import ForgeSwift

struct StepperDemo: ModelView {
    func model(context: ViewContext) -> StepperDemoModel { StepperDemoModel(context: context) }
    func builder(model: StepperDemoModel) -> StepperDemoBuilder { StepperDemoBuilder(model: model) }
}

final class StepperDemoModel: ViewModel<StepperDemo> {
    var count = Binding(0)
}

final class StepperDemoBuilder: ViewBuilder<StepperDemoModel> {
    override func build(context: ViewContext) -> any View {
        DemoScreen( "Stepper") {
            DemoSection("Integer") {
                Stepper(value: model.count, range: 0...100, step: 1)
            }
        }
    }
}
