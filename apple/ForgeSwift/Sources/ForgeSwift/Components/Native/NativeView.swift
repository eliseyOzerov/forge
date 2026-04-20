#if canImport(UIKit)
import UIKit

// MARK: - NativeView

/// Hosts any UIKit view inside the Forge view tree. The platform
/// view is created once via `create` and persisted across rebuilds;
/// `configure` is called on every update to apply new props.
///
/// ```swift
/// NativeView<UITextField>(
///     create: { UITextField() },
///     configure: { field in
///         field.text = model.text
///         field.font = style.font.resolvedFont
///     }
/// )
/// ```
public struct NativeView<V: UIView>: LeafView {
    public let create: @MainActor () -> V
    public let configure: @MainActor (V) -> Void

    public init(
        create: @escaping @MainActor () -> V,
        configure: @escaping @MainActor (V) -> Void
    ) {
        self.create = create
        self.configure = configure
    }

    public func makeRenderer() -> Renderer {
        NativeRenderer<V>(view: self)
    }
}

// MARK: - Renderer

final class NativeRenderer<V: UIView>: Renderer {
    private weak var nativeView: V?
    private var view: NativeView<V>

    init(view: NativeView<V>) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let native = newView as? NativeView<V>, let nativeView else { return }
        view = native
        view.configure(nativeView)
    }

    func mount() -> PlatformView {
        let v = view.create()
        nativeView = v
        view.configure(v)
        return v
    }
}

#endif
