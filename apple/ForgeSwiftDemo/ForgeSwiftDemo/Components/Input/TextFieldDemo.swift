import ForgeSwift

struct TextFieldDemo: ModelView {
    func model(context: ViewContext) -> TextFieldDemoModel { TextFieldDemoModel(context: context) }
    func builder(model: TextFieldDemoModel) -> TextFieldDemoBuilder { TextFieldDemoBuilder(model: model) }
}

final class TextFieldDemoModel: ViewModel<TextFieldDemo> {
    var text = Binding("")
    var email = Binding("")
}

final class TextFieldDemoBuilder: ViewBuilder<TextFieldDemoModel> {
    override func build(context: ViewContext) -> any View {
        demoScreen(title: "TextField") {
            demoSection("Basic") {
                TextField(text: model.text, decoration: TextFieldDecoration(placeholder: "Type something..."))
            }
            demoSection("With label") {
                TextField(text: model.email, decoration: TextFieldDecoration(placeholder: "you@example.com", label: "Email"))
            }
        }
    }
}
