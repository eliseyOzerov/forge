import ForgeSwift

struct ToggleDemo: ModelView {
    func model(context: ViewContext) -> ToggleDemoModel { ToggleDemoModel(context: context) }
    func builder(model: ToggleDemoModel) -> ToggleDemoBuilder { ToggleDemoBuilder(model: model) }
}

final class ToggleDemoModel: ViewModel<ToggleDemo> {
    var switchValue = Binding(true)
    var checkValue = Binding(false)
}

final class ToggleDemoBuilder: ViewBuilder<ToggleDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "Toggle") {
            demoSection("Switch") {
                demoRow("Enabled", child: Toggle(value: model.switchValue, style: .constant(ToggleStyle(painter: SwitchPainter()))))
            }
            demoSection("Checkbox") {
                demoRow("Checked", child: Toggle(value: model.checkValue))
            }
        }
    }
}
