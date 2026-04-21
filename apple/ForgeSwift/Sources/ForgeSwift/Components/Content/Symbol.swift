// MARK: - Symbol

/// Platform system icon (SF Symbols on Apple, Material Symbols on Android).
public struct Symbol: LeafView {
    public var name: String
    public var style: SymbolStyle

    public init(_ name: String, style: SymbolStyle = SymbolStyle()) {
        self.name = name
        self.style = style
    }

    /// Configure style. The callback receives the current style for modification.
    public func style(_ build: (SymbolStyle) -> SymbolStyle) -> Symbol {
        var copy = self
        copy.style = build(style)
        return copy
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        UIKitSymbolRenderer(view: self)
        #else
        fatalError("Symbol not yet implemented for this platform")
        #endif
    }
}

// MARK: - SymbolStyle

/// Visual style for a symbol (size, weight, color, rendering mode, scale, variable value).
@Init @Copy
public struct SymbolStyle {
    public var size: Double = 24
    @Snap public var weight: Weight? = nil
    public var color: Color? = nil
    @Snap public var scale: SymbolScale = .medium
    @Snap public var mode: SymbolMode = .monochrome
    public var value: Double? = nil
}

/// Symbol scale relative to adjacent text.
public enum SymbolScale: Sendable, Equatable {
    case small, medium, large
}

/// How a symbol's colors are applied.
public enum SymbolMode: Sendable, Equatable {
    case monochrome
    case hierarchical
    case palette(Color, Color, Color?)
    case multicolor
}

// MARK: - SymbolRole

/// Named symbol role token.
public struct SymbolRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension SymbolRole {
    static let primary    = SymbolRole("primary")
    static let secondary  = SymbolRole("secondary")
    static let tertiary   = SymbolRole("tertiary")
    static let quaternary = SymbolRole("quaternary")

    static let defaultChain: [SymbolRole] = [.primary, .secondary, .tertiary, .quaternary]
}

// MARK: - SymbolTheme

/// Theme for symbols with per-role defaults.
public struct SymbolTheme: Copyable {
    public var styles: [SymbolRole: SymbolStyle]
    public var chain: [SymbolRole]

    public init(_ styles: [SymbolRole: SymbolStyle], chain: [SymbolRole] = SymbolRole.defaultChain) {
        self.styles = styles
        self.chain = chain
    }

    public init(_ priority: PriorityTokens<SymbolStyle>) {
        var map: [SymbolRole: SymbolStyle] = [:]
        for (level, style) in priority.values {
            map[SymbolRole(level.name)] = style
        }
        self.init(map)
    }

    public init(
        primary: SymbolStyle,
        secondary: SymbolStyle? = nil,
        tertiary: SymbolStyle? = nil,
        quaternary: SymbolStyle? = nil
    ) {
        self.init(PriorityTokens(
            primary: primary, secondary: secondary,
            tertiary: tertiary, quaternary: quaternary
        ))
    }

    public subscript(_ role: SymbolRole) -> SymbolStyle {
        styles.cascade(role, chain: chain) ?? SymbolStyle()
    }

    public var primary:    SymbolStyle { self[.primary] }
    public var secondary:  SymbolStyle { self[.secondary] }
    public var tertiary:   SymbolStyle { self[.tertiary] }
    public var quaternary: SymbolStyle { self[.quaternary] }

    public static func standard() -> SymbolTheme {
        SymbolTheme(primary: SymbolStyle())
    }
}

public extension ThemeSlot where T == SymbolTheme {
    static var symbol: ThemeSlot<SymbolTheme> { .init(SymbolTheme.self) }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

extension Weight {
    var uiSymbolWeight: UIImage.SymbolWeight {
        switch self {
        case .ultraLight: .ultraLight; case .thin: .thin; case .light: .light
        case .regular: .regular; case .medium: .medium; case .semibold: .semibold
        case .bold: .bold; case .heavy: .heavy; case .black: .black
        case .numeric(let n):
            switch n {
            case ...149: .ultraLight
            case 150...249: .thin
            case 250...349: .light
            case 350...449: .regular
            case 450...549: .medium
            case 550...649: .semibold
            case 650...749: .bold
            case 750...849: .heavy
            default: .black
            }
        }
    }
}

extension SymbolScale {
    var uiSymbolScale: UIImage.SymbolScale {
        switch self {
        case .small: .small; case .medium: .medium; case .large: .large
        }
    }
}

final class UIKitSymbolRenderer: Renderer {
    private weak var imageView: UIImageView?
    private var view: Symbol

    init(view: Symbol) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let symbol = newView as? Symbol, let imageView else { return }
        let old = view
        view = symbol

        let nameChanged = old.name != symbol.name
        let configChanged = old.style.size != symbol.style.size
            || old.style.weight != symbol.style.weight
            || old.style.scale != symbol.style.scale
            || old.style.value != symbol.style.value
        let modeChanged = old.style.mode != symbol.style.mode
        let colorChanged = old.style.color != symbol.style.color

        if nameChanged || configChanged || modeChanged {
            applySymbolImage(to: imageView)
            imageView.superview?.setNeedsLayout()
        } else if colorChanged {
            if case .monochrome = symbol.style.mode {
                imageView.tintColor = symbol.style.color?.platformColor ?? .label
            }
        }
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        self.imageView = imageView
        applySymbolImage(to: imageView)
        return imageView
    }

    private func applySymbolImage(to imageView: UIImageView) {
        var config: UIImage.SymbolConfiguration = .init(
            pointSize: view.style.size,
            weight: view.style.weight?.uiSymbolWeight ?? .regular,
            scale: view.style.scale.uiSymbolScale
        )

        switch view.style.mode {
        case .monochrome:
            config = config.applying(UIImage.SymbolConfiguration.preferringMonochrome())
        case .hierarchical:
            let color = view.style.color?.platformColor ?? .label
            config = config.applying(UIImage.SymbolConfiguration(hierarchicalColor: color))
        case .multicolor:
            config = config.applying(UIImage.SymbolConfiguration.preferringMulticolor())
        case .palette(let primary, let secondary, let tertiary):
            let colors: [UIColor]
            if let t = tertiary {
                colors = [primary.platformColor, secondary.platformColor, t.platformColor]
            } else {
                colors = [primary.platformColor, secondary.platformColor]
            }
            config = config.applying(UIImage.SymbolConfiguration(paletteColors: colors))
        }

        var image: UIImage?
        if let value = view.style.value {
            image = UIImage(systemName: view.name, variableValue: value, configuration: config)
        } else {
            image = UIImage(systemName: view.name, withConfiguration: config)
        }

        if case .monochrome = view.style.mode {
            image = image?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = view.style.color?.platformColor ?? .label
        } else {
            image = image?.withRenderingMode(.alwaysOriginal)
        }

        imageView.image = image
    }
}

#endif
