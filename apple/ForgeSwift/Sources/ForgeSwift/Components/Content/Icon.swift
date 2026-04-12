#if canImport(UIKit)
import UIKit

/// An icon component. On Apple platforms, renders SF Symbols via
/// UIImageView. Takes an IconName (which is just a string wrapper
/// for autocomplete) plus style options.
public struct Icon: LeafView {
    public let name: IconName
    public let style: IconStyle

    public init(_ name: IconName, style: IconStyle = IconStyle()) {
        self.name = name
        self.style = style
    }

    public func makeRenderer() -> Renderer {
        UIKitIconRenderer(name: name, style: style)
    }
}

// MARK: - IconName

/// A symbol name. ExpressibleByStringLiteral so you can write
/// `Icon("checkmark")` or `Icon(.checkmark)` (once generated constants exist).
public struct IconName: ExpressibleByStringLiteral, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - IconStyle

public struct IconStyle {
    public var size: Double
    public var weight: IconWeight
    public var color: Color?
    public var renderingMode: IconRenderingMode

    public init(
        size: Double = 24,
        weight: IconWeight = .regular,
        color: Color? = nil,
        renderingMode: IconRenderingMode = .template
    ) {
        self.size = size
        self.weight = weight
        self.color = color
        self.renderingMode = renderingMode
    }
}

public enum IconWeight: Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var uiSymbolWeight: UIImage.SymbolWeight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

public enum IconRenderingMode: Sendable {
    case template
    case original
    case hierarchical
    case palette

    var isTemplate: Bool {
        self == .template
    }
}

// MARK: - Renderer

final class UIKitIconRenderer: Renderer {
    let name: IconName
    let style: IconStyle

    init(name: IconName, style: IconStyle) {
        self.name = name
        self.style = style
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        apply(to: imageView)
        return imageView
    }

    func update(_ platformView: PlatformView) {
        guard let imageView = platformView as? UIImageView else { return }
        apply(to: imageView)
    }

    private func apply(to imageView: UIImageView) {
        let config = UIImage.SymbolConfiguration(pointSize: style.size, weight: style.weight.uiSymbolWeight)
        var image = UIImage(systemName: name.rawValue, withConfiguration: config)

        if style.renderingMode.isTemplate {
            image = image?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = style.color?.platformColor ?? .label
        } else {
            image = image?.withRenderingMode(.alwaysOriginal)
        }

        imageView.image = image
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
    }
}

#else

public struct Icon: ComposedView {
    public init() {}
    public func build(context: BuildContext) -> any View { Text("TODO: Icon") }
}

#endif
