#if canImport(UIKit)
import UIKit

/// A tappable component. Wraps a body (any View) in an interactive
/// container with state-reactive styling.
///
/// ```swift
/// Button(onTap: { print("tapped") }) {
///     Text("Tap me")
/// }
///
/// Button(
///     "Submit",
///     style: StateProperty { state in
///         BoxStyle(
///             .fillWidth.height(.fix(48)),
///             state.contains(.pressed)
///                 ? .color(Color(0.1, 0.4, 0.9))
///                 : .color(Color(0.2, 0.5, 1.0)),
///             .capsule(),
///             padding: Padding(horizontal: 16)
///         )
///     },
///     onTap: { }
/// )
/// ```
public struct Button: ModelView {
    public let body: any View
    public let style: StateProperty<BoxStyle>
    public let onTap: @MainActor () -> Void
    public let disabled: Bool

    /// Body-based button with custom content.
    public init(
        style: StateProperty<BoxStyle> = .constant(BoxStyle()),
        disabled: Bool = false,
        onTap: @escaping @MainActor () -> Void,
        @ChildrenBuilder body: () -> [any View]
    ) {
        let children = body()
        self.body = children.count == 1 ? children[0] : Box(children: children)
        self.style = style
        self.onTap = onTap
        self.disabled = disabled
    }

    /// Text shortcut.
    public init(
        _ title: String,
        style: StateProperty<BoxStyle> = .constant(BoxStyle()),
        disabled: Bool = false,
        onTap: @escaping @MainActor () -> Void
    ) {
        self.body = Text(title)
        self.style = style
        self.onTap = onTap
        self.disabled = disabled
    }

    public func makeModel(context: BuildContext) -> ButtonModel { ButtonModel() }
    public func makeBuilder() -> ButtonBuilder { ButtonBuilder() }
}

// MARK: - Model

public final class ButtonModel: ViewModel<Button> {
    var isPressed = false
    var onTap: (@MainActor () -> Void)?

    public override func didInit() {
        onTap = view.onTap
    }

    public override func didUpdate(from oldView: Button) {
        onTap = view.onTap
    }

    var currentState: UIState {
        var state: UIState = .idle
        if isPressed { state.insert(.pressed) }
        if view.disabled { state.insert(.disabled) }
        return state
    }

    func handlePress() {
        guard !view.disabled else { return }
        rebuild { isPressed = true }
    }

    func handleRelease(inside: Bool) {
        rebuild { isPressed = false }
        if inside { onTap?() }
    }
}

// MARK: - Builder

public final class ButtonBuilder: ViewBuilder<ButtonModel> {
    public override func build(context: BuildContext) -> any View {
        let style = model.view.style(model.currentState)
        return TappableBox(style, model: model) {
            model.view.body
        }
    }
}

// MARK: - TappableBox

/// A Box that handles touch events and forwards to ButtonModel.
struct TappableBox: ContainerView {
    let boxStyle: BoxStyle
    let model: ButtonModel
    let children: [any View]

    init(_ style: BoxStyle, model: ButtonModel, @ChildrenBuilder content: () -> [any View]) {
        self.boxStyle = style
        self.model = model
        self.children = content()
    }

    func makeRenderer() -> ContainerRenderer {
        TappableBoxRenderer(style: boxStyle, model: model)
    }
}

final class TappableBoxRenderer: ContainerRenderer {
    let style: BoxStyle
    let model: ButtonModel

    init(style: BoxStyle, model: ButtonModel) {
        self.style = style
        self.model = model
    }

    func mount() -> PlatformView {
        let view = TappableBoxView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? TappableBoxView else { return }
        apply(to: view)
    }

    private func apply(to view: TappableBoxView) {
        view.boxFrame = style.frame
        view.boxShape = style.shape
        view.boxSurface = style.surface
        view.boxClip = style.clip
        view.boxPadding = style.padding
        view.boxAlignment = style.alignment
        view.boxOverflow = style.overflow
        view.buttonModel = model
        view.isUserInteractionEnabled = true
        view.setNeedsDisplay()
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - TappableBoxView

final class TappableBoxView: BoxView {
    weak var buttonModel: ButtonModel?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        buttonModel?.handlePress()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let inside = touches.first.map { bounds.contains($0.location(in: self)) } ?? false
        buttonModel?.handleRelease(inside: inside)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        buttonModel?.handleRelease(inside: false)
    }
}

#endif
