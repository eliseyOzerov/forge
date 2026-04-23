/// A single-child wrapper that carries typed data for the parent layout container.
///
/// Parent containers read the data by checking `if let host = childView as? ParentDataView<MyData>`.
/// This avoids coupling children to specific layout systems while keeping the data strongly typed.
///
/// ```swift
/// // Define data for your layout:
/// struct FlexData { var flex: Double = 1; var stretch: Bool = false }
///
/// // Wrap a child:
/// ParentData(FlexData(flex: 2)) { Text("Hello") }
///
/// // Read in the parent's layout:
/// if let host = childView as? ParentDataView<FlexData> {
///     host.data.flex  // 2.0
/// }
/// ```
public struct ParentData<T: Sendable>: ProxyView {
    public let data: T
    public let child: any View

    public init(_ data: T, @ChildBuilder content: () -> any View) {
        self.data = data
        self.child = content()
    }

    public func makeRenderer() -> ProxyRenderer {
        #if canImport(UIKit)
        ParentDataRenderer(data: data)
        #else
        fatalError("ParentData not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

final class ParentDataRenderer<T: Sendable>: ProxyRenderer {
    weak var node: ProxyNode?
    var data: T

    init(data: T) {
        self.data = data
    }

    func mount() -> PlatformView {
        let view = ParentDataView<T>()
        view.data = data
        return view
    }

    func update(from newView: any View) {
        guard let pd = newView as? ParentData<T>,
              let host = node?.platformView as? ParentDataView<T> else { return }
        data = pd.data
        host.data = pd.data
    }
}

/// Passthrough UIView that carries typed parent data.
/// Delegates sizing and layout to its single child.
final class ParentDataView<T>: PassthroughView {
    var data: T!
}

/// Extract parent data of a given type from a platform view,
/// unwrapping through PassthroughView if needed.
func parentData<T>(_ type: T.Type, from view: UIView) -> T? {
    if let host = view as? ParentDataView<T> { return host.data }
    if let proxy = view as? PassthroughView,
       let host = proxy.subviews.first as? ParentDataView<T> { return host.data }
    return nil
}

#endif
