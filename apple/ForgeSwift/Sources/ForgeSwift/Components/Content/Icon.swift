#if canImport(UIKit)
import UIKit

public struct Icon: LeafView {
    public let name: String
    public let style: IconStyle

    public init(_ name: String, style: IconStyle = IconStyle()) {
        self.name = name
        self.style = style
    }

    public func makeRenderer() -> Renderer {
        UIKitIconRenderer(view: self)
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
        case .ultraLight: .ultraLight; case .thin: .thin; case .light: .light
        case .regular: .regular; case .medium: .medium; case .semibold: .semibold
        case .bold: .bold; case .heavy: .heavy; case .black: .black
        }
    }
}

public enum IconRenderingMode: Sendable {
    case template, original, hierarchical, palette

    var isTemplate: Bool { self == .template }
}

// MARK: - Renderer

final class UIKitIconRenderer: Renderer {
    private weak var imageView: UIImageView?
    private var view: Icon

    init(view: Icon) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let icon = newView as? Icon, let imageView else { return }
        let old = view
        view = icon

        let nameChanged = old.name != icon.name
        let sizeChanged = old.style.size != icon.style.size || old.style.weight != icon.style.weight
        let renderingChanged = old.style.renderingMode != icon.style.renderingMode
        let colorChanged = old.style.color != icon.style.color

        if nameChanged || sizeChanged || renderingChanged {
            applyIconImage(to: imageView)
            imageView.superview?.setNeedsLayout()
        } else if colorChanged {
            if icon.style.renderingMode.isTemplate {
                imageView.tintColor = icon.style.color?.platformColor ?? .label
            }
        }
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        self.imageView = imageView
        applyIconImage(to: imageView)
        return imageView
    }

    private func applyIconImage(to imageView: UIImageView) {
        let config = UIImage.SymbolConfiguration(pointSize: view.style.size, weight: view.style.weight.uiSymbolWeight)
        var image = UIImage(systemName: view.name, withConfiguration: config)

        if view.style.renderingMode.isTemplate {
            image = image?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = view.style.color?.platformColor ?? .label
        } else {
            image = image?.withRenderingMode(.alwaysOriginal)
        }

        imageView.image = image
    }
}

#else

public struct Icon: BuiltView {
    public init() {}
    public func build(context: BuildContext) -> any View { Text("TODO: Icon") }
}

#endif

// MARK: - IconRole

public struct IconRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension IconRole {
    static let primary    = IconRole("primary")
    static let secondary  = IconRole("secondary")
    static let tertiary   = IconRole("tertiary")
    static let quaternary = IconRole("quaternary")

    static let defaultChain: [IconRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - IconTheme

public struct IconTheme: Copyable {
    public var styles: [IconRole: IconStyle]
    public var chain: [IconRole]

    public init(_ styles: [IconRole: IconStyle], chain: [IconRole] = IconRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<IconStyle>) {
        var map: [IconRole: IconStyle] = [:]
        for (level, style) in priority.values {
            map[IconRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: IconStyle,
        secondary: IconStyle? = nil,
        tertiary: IconStyle? = nil,
        quaternary: IconStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: IconRole) -> IconStyle {
        styles.cascade(role, chain: chain) ?? IconStyle()
    }

    public var primary:    IconStyle { self[.primary] }
    public var secondary:  IconStyle { self[.secondary] }
    public var tertiary:   IconStyle { self[.tertiary] }
    public var quaternary: IconStyle { self[.quaternary] }

    public static func standard() -> IconTheme {
        IconTheme(primary: IconStyle())
    }
}

public extension ThemeSlot where T == IconTheme {
    static var icon: ThemeSlot<IconTheme> { .init(IconTheme.self) }
}
