/// Weight-based flex child wrapper. Tells a `Row`/`Column` to distribute
/// remaining space to this child by weight. Has no effect outside flex layouts.
///
/// Use via the `.flexible()` view extension rather than constructing directly.
public struct Flexible: ProxyView {
    public let child: any View
    public var weight: Int
    public var min: Double?
    public var max: Double?

    public init(weight: Int = 1, min: Double? = nil, max: Double? = nil, @ChildBuilder content: () -> any View) {
        self.child = content()
        self.weight = weight
        self.min = min
        self.max = max
    }

    public func makeRenderer() -> ProxyRenderer {
        #if canImport(UIKit)
        FlexibleRenderer(weight: weight, min: min, max: max)
        #else
        fatalError("Flexible not yet implemented for this platform")
        #endif
    }
}

// MARK: - View Extension

public extension View {
    /// Wrap this view as a flex child with the given weight.
    func flex(_ weight: Int = 1, min: Double? = nil, max: Double? = nil) -> Flexible {
        Flexible(weight: weight, min: min, max: max) { self }
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class FlexibleRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    var weight: Int
    var min: Double?
    var max: Double?

    init(weight: Int, min: Double?, max: Double?) {
        self.weight = weight
        self.min = min
        self.max = max
    }

    func mount() -> PlatformView {
        let view = FlexibleHostView()
        view.weight = weight
        view.flexMin = min
        view.flexMax = max
        return view
    }

    func update(from newView: any View) {
        guard let flexible = newView as? Flexible,
              let host = node?.platformView as? FlexibleHostView else { return }
        weight = flexible.weight
        min = flexible.min
        max = flexible.max
        host.weight = flexible.weight
        host.flexMin = flexible.min
        host.flexMax = flexible.max
    }
}

/// Passthrough UIView that carries flex weight metadata.
/// Delegates sizing and layout to its single child.
final class FlexibleHostView: UIView {
    var weight: Int = 1
    var flexMin: Double?
    var flexMax: Double?

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds
    }
}

#endif
