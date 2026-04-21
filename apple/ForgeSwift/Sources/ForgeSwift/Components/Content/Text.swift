import CoreText

// MARK: - Text

/// Text component that displays styled string content.
public struct Text: BuiltView {
    public var content: String
    public var style: TextStyle

    public init(_ content: String, style: TextStyle = TextStyle()) {
        self.content = content
        self.style = style
    }

    /// Configure style. The callback receives the current style for modification.
    public func style(_ build: (TextStyle) -> TextStyle) -> Text {
        var copy = self
        copy.style = build(style)
        return copy
    }

    public func build(context: ViewContext) -> any View {
        let provided = context.tryRead(TextStyle.self)
        let resolved = provided != nil ? style.merge(provided!) : style
        return TextLeaf(content: content, style: resolved)
    }
}

// MARK: - TextStyle

/// Visual style for text (font, color, alignment, decoration, overflow).
@Style
public struct TextStyle: Sendable, Equatable {
    public var font: Font?
    public var color: Color?
    @Snap public var maxLines: Int?
    @Snap public var align: TextAlign?
    @Snap public var textCase: TextCase?
    @Snap public var overflow: TextOverflow?
    @Snap public var decoration: TextDecoration?
}

/// Resolved text leaf view with fully merged style, ready for rendering.
struct TextLeaf: LeafView {
    let content: String
    let style: TextStyle

    func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        UIKitTextRenderer(view: self)
        #elseif canImport(AppKit)
        AppKitTextRenderer(content: content)
        #else
        fatalError("Text not yet implemented for this platform")
        #endif
    }
}

// MARK: - Font

/// Font descriptor with family, size, weight, tracking, and variable-font features.
@Init @Copy @Lerp
public struct Font: Sendable, Equatable {
    @Snap public var family: String?
    public var size: Double = 17
    public var height: Double = 1.2
    public var tracking: Double = 0
    public var weight: Double = 400
    @Snap public var italic: Bool = false
    @Snap public var features: FontFeatures?

    public var resolvedLineSpacing: Double {
        max(0, (height - 1.0) * size)
    }

    static func tagToNumber(_ tag: String) -> Int {
        let bytes = Array(tag.utf8)
        guard bytes.count == 4 else { return 0 }
        return Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
    }
}

// MARK: - TextAlign

/// Horizontal text alignment (leading, trailing, center, justify).
public enum TextAlign: String, Sendable {
    case leading
    case trailing
    case center
    case justify
}

// MARK: - TextOverflow

/// How text is clipped when it overflows its container.
public enum TextOverflow: String, Sendable {
    case clip
    case ellipsis
}

// MARK: - TextCase

/// Text casing transform.
public enum TextCase: String, Sendable {
    case plain
    case uppercase
    case lowercase
    case capitalize
    case title
    case pascal
    case camel
    case snake
    case kebab
    case dot
    case sponge

    public func apply(to text: String) -> String {
        switch self {
        case .plain: return text
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        case .capitalize: return text.prefix(1).uppercased() + text.dropFirst()
        case .title: return text.capitalized
        case .pascal: return text.splitWords().map(\.capitalized).joined()
        case .camel:
            let words = text.splitWords()
            guard let first = words.first else { return text }
            return first.lowercased() + words.dropFirst().map(\.capitalized).joined()
        case .snake: return text.splitWords().map { $0.lowercased() }.joined(separator: "_")
        case .kebab: return text.splitWords().map { $0.lowercased() }.joined(separator: "-")
        case .dot: return text.splitWords().map { $0.lowercased() }.joined(separator: ".")
        case .sponge: return String(text.enumerated().map { i, c in i.isMultiple(of: 2)
            ? Character(c.lowercased())
            : Character(c.uppercased()) })
        }
    }
}

private extension String {
    func splitWords() -> [String] {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Already delimited by non-alphanumeric characters
        let explicit = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        if explicit.count > 1 { return explicit }

        // camelCase / PascalCase boundary split
        var words: [String] = []
        var current = ""
        for char in trimmed {
            if char.isUppercase && !current.isEmpty {
                words.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

// MARK: - TextDecoration

/// Decorations applied to text (underline, strikethrough, shadow).
@Init
public struct TextDecoration: Sendable, Equatable {
    public var underline: TextLineStyle?
    public var strikethrough: TextLineStyle?
    public var shadow: ShadowConfig?
}

// MARK: - FontFeatures

/// OpenType font features: stylistic sets, character alternates, and variation axes.
@Init
public struct FontFeatures: Sendable, Equatable {
    public var stylisticSets: Set<Int> = []
    public var alternates: [Int: Int] = [:]
    public var axes: [FontAxis: Double] = [:]
    public var rawTags: Set<String> = []
}

// MARK: - FontAxis

/// Variable font axis identifiers (weight, width, slant, etc.).
public enum FontAxis: String, CaseIterable, Sendable {
    case weight = "wght"
    case width = "wdth"
    case slant = "slnt"
    case italic = "ital"
    case opticalSize = "opsz"
    case fill = "FILL"
    case grade = "GRAD"
    case monospace = "MONO"
    case casualness = "CASL"
    case cursive = "CRSV"
    case softness = "SOFT"
    case roundness = "ROND"

    public var code: String { rawValue }
}

// MARK: - TextLineStyle

/// Visual style for an underline or strikethrough line.
@Init
public struct TextLineStyle: Sendable, Equatable {
    public var color: Color?
    public var style: Int = 0x01

    public static let single = 0x01
    public static let double = 0x09
    public static let thick = 0x02
}

// MARK: - ShadowConfig

/// Text shadow configuration (color, blur radius, offset).
@Init
public struct ShadowConfig: Sendable, Equatable {
    public var color: Color = Color.black.withAlpha(0.33)
    public var radius: Double = 1
    public var offset: Size = Size(0, 1)
}

// MARK: - TextSize

/// Named text size token for the text theme.
public struct TextSize: TokenKey {
    public let name: String
    public let defaultValue: Double

    public init(_ name: String, _ defaultValue: Double) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension TextSize {
    static let xxs = TextSize("xxs", 10)
    static let xs  = TextSize("xs",  12)
    static let sm  = TextSize("sm",  14)
    static let rg  = TextSize("rg",  16)
    static let md  = TextSize("md",  18)
    static let lg  = TextSize("lg",  20)
    static let xl  = TextSize("xl",  24)
    static let xl2 = TextSize("xl2", 32)
    static let xl3 = TextSize("xl3", 40)
    static let xl4 = TextSize("xl4", 64)
    static let xl5 = TextSize("xl5", 96)
}

// MARK: - TextWeight

/// Weight ramp — values map to variable-font `wght` axis numbers
/// (100..900) and pass through to `Font.weight`.
public struct TextWeight: TokenKey {
    public let name: String
    public let defaultValue: Double

    public init(_ name: String, _ defaultValue: Double) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension TextWeight {
    static let hair     = TextWeight("hair",     100)
    static let thin     = TextWeight("thin",     200)
    static let light    = TextWeight("light",    300)
    static let regular  = TextWeight("regular",  400)
    static let medium   = TextWeight("medium",   500)
    static let semibold = TextWeight("semibold", 600)
    static let bold     = TextWeight("bold",     700)
    static let heavy    = TextWeight("heavy",    800)
    static let black    = TextWeight("black",    900)
}

// MARK: - TextLineHeight

/// Named multipliers applied to the resolved font size.
public struct TextLineHeight: TokenKey {
    public let name: String
    public let defaultValue: Double

    public init(_ name: String, _ defaultValue: Double) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension TextLineHeight {
    static let word      = TextLineHeight("word",      1.0)
    static let sentence  = TextLineHeight("sentence",  1.2)
    static let paragraph = TextLineHeight("paragraph", 1.5)
    static let heading   = TextLineHeight("heading",   1.8)
}

// MARK: - TextRole

/// Semantic text role. Pure NamedKey — the theme decides what a role
/// resolves to when unpopulated (falls back to TextTheme.primary),
/// so there's no intrinsic default on the key itself.
public struct TextRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension TextRole {
    static let display = TextRole("display")
    static let value   = TextRole("value")
    static let title   = TextRole("title")
    static let body    = TextRole("body")
    static let label   = TextRole("label")
}

// MARK: - RoleTheme

/// Per-role text style configuration with size overrides.
public struct RoleTheme: Sendable, Copyable {
    /// Base Font for this role. Covers any unpopulated TextSize by
    /// scaling to that size's default points.
    public var primary: Font
    public var sizes: [TextSize: Font]

    public init(primary: Font, sizes: [TextSize: Font] = [:]) {
        self.primary = primary
        self.sizes = sizes
    }

    public subscript(_ size: TextSize) -> Font {
        if let explicit = sizes[size] { return explicit }
        var font = primary
        font.size = CGFloat(size.defaultValue)
        return font
    }

    public var xxs: Font { self[.xxs] }
    public var xs:  Font { self[.xs] }
    public var sm:  Font { self[.sm] }
    public var rg:  Font { self[.rg] }
    public var md:  Font { self[.md] }
    public var lg:  Font { self[.lg] }
    public var xl:  Font { self[.xl] }
    public var xl2: Font { self[.xl2] }
    public var xl3: Font { self[.xl3] }
    public var xl4: Font { self[.xl4] }
    public var xl5: Font { self[.xl5] }
}

// MARK: - TextTheme

/// Complete text theme with sizes, weights, line heights, and roles.
public struct TextTheme: Sendable, Copyable {
    public var primary: Font
    public var roles: [TextRole: RoleTheme]

    public init(primary: Font, roles: [TextRole: RoleTheme] = [:]) {
        self.primary = primary
        self.roles = roles
    }

    public subscript(_ role: TextRole) -> RoleTheme {
        roles[role] ?? RoleTheme(primary: primary)
    }

    public var display: RoleTheme { self[.display] }
    public var value:   RoleTheme { self[.value] }
    public var title:   RoleTheme { self[.title] }
    public var body:    RoleTheme { self[.body] }
    public var label:   RoleTheme { self[.label] }

    public static func standard(primary: Font = Font()) -> TextTheme {
        TextTheme(
            primary: primary,
            roles: [
                .display: RoleTheme(primary: primary.withWeight(.bold).withTracking(-0.5)),
                .value:   RoleTheme(primary: primary.withWeight(.semibold).withTracking(-0.2)),
                .title:   RoleTheme(primary: primary.withWeight(.semibold)),
                .body:    RoleTheme(primary: primary.withWeight(.regular)),
                .label:   RoleTheme(primary: primary.withWeight(.medium).withTracking(0.3)),
            ]
        )
    }
}

// MARK: - Font conveniences

public extension Font {
    func withWeight(_ weight: TextWeight) -> Font {
        var copy = self
        copy.weight = CGFloat(weight.defaultValue)
        return copy
    }

    func withTracking(_ tracking: Double) -> Font {
        var copy = self
        copy.tracking = CGFloat(tracking)
        return copy
    }

    func withSize(_ size: TextSize) -> Font {
        var copy = self
        copy.size = CGFloat(size.defaultValue)
        return copy
    }

    func withLineHeight(_ lh: TextLineHeight) -> Font {
        var copy = self
        copy.height = CGFloat(lh.defaultValue)
        return copy
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

extension Font {
    public var resolvedFont: UIFont {
        var descriptor = baseDescriptor
        descriptor = applyVariations(to: descriptor)
        descriptor = applyFeatureSettings(to: descriptor)
        if italic {
            descriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    private var baseDescriptor: UIFontDescriptor {
        if let family {
            return UIFontDescriptor(fontAttributes: [.family: family])
        } else {
            return UIFont.systemFont(ofSize: size).fontDescriptor
        }
    }

    private func applyVariations(to descriptor: UIFontDescriptor) -> UIFontDescriptor {
        let info = FontInfo.query(family: family)
        var variations: [Int: Double] = [:]

        if info.hasWeightAxis {
            variations[Self.tagToNumber("wght")] = weight
        }

        if let axes = features?.axes {
            for (axis, value) in axes {
                variations[Self.tagToNumber(axis.code)] = value
            }
        }

        var result = descriptor

        if !variations.isEmpty {
            result = result.addingAttributes([
                .init(rawValue: kCTFontVariationAttribute as String): variations
            ])
        }

        if !info.hasWeightAxis {
            let uiFontWeight = Self.uiFontWeight(from: weight)
            result = result.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: uiFontWeight],
            ])
        }

        return result
    }

    private func applyFeatureSettings(to descriptor: UIFontDescriptor) -> UIFontDescriptor {
        guard let features else { return descriptor }
        var settings: [[String: Any]] = []

        for ss in features.stylisticSets where (1...20).contains(ss) {
            let tag = String(format: "ss%02d", ss)
            settings.append(featureEntry(tag: tag, value: 1))
        }

        for (index, value) in features.alternates where (1...99).contains(index) {
            let tag = String(format: "cv%02d", index)
            settings.append(featureEntry(tag: tag, value: value))
        }

        for tag in features.rawTags {
            settings.append(featureEntry(tag: tag, value: 1))
        }

        guard !settings.isEmpty else { return descriptor }

        return descriptor.addingAttributes([
            .featureSettings: settings
        ])
    }

    private func featureEntry(tag: String, value: Int) -> [String: Any] {
        [
            kCTFontOpenTypeFeatureTag as String: tag,
            kCTFontOpenTypeFeatureValue as String: value,
        ]
    }

    private static func uiFontWeight(from weight: Double) -> UIFont.Weight {
        let stops: [(Double, CGFloat)] = [
            (100, UIFont.Weight.ultraLight.rawValue),
            (200, UIFont.Weight.thin.rawValue),
            (300, UIFont.Weight.light.rawValue),
            (400, UIFont.Weight.regular.rawValue),
            (500, UIFont.Weight.medium.rawValue),
            (600, UIFont.Weight.semibold.rawValue),
            (700, UIFont.Weight.bold.rawValue),
            (800, UIFont.Weight.heavy.rawValue),
            (900, UIFont.Weight.black.rawValue),
        ]

        if weight <= stops.first!.0 { return UIFont.Weight(rawValue: stops.first!.1) }
        if weight >= stops.last!.0 { return UIFont.Weight(rawValue: stops.last!.1) }

        for i in 0..<stops.count - 1 {
            let (w0, v0) = stops[i]
            let (w1, v1) = stops[i + 1]
            if weight >= w0 && weight <= w1 {
                let t = (weight - w0) / (w1 - w0)
                return UIFont.Weight(rawValue: v0 + t * (v1 - v0))
            }
        }

        return .regular
    }
}

extension TextAlign {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: return .natural
        case .trailing:
            let isRTL = NSParagraphStyle.defaultWritingDirection(forLanguage: "") == .rightToLeft
            return isRTL ? .left : .right
        case .center: return .center
        case .justify: return .justified
        }
    }
}

extension TextOverflow {
    var lineBreakMode: NSLineBreakMode {
        switch self {
        case .clip: .byClipping
        case .ellipsis: .byTruncatingTail
        }
    }
}

/// Queried font metadata including available variation axes.
struct FontInfo {
    let variationAxes: [VariationAxisInfo]

    var hasWeightAxis: Bool { variationAxes.contains { $0.tag == "wght" } }

    private nonisolated(unsafe) static var cache: [String: FontInfo] = [:]
    private static let cacheKey = "__system__"

    static func query(family: String?) -> FontInfo {
        let key = family ?? cacheKey
        if let cached = cache[key] { return cached }
        let result = resolve(family: family)
        cache[key] = result
        return result
    }

    private static func resolve(family: String?) -> FontInfo {
        let uiFont: UIFont
        if let family {
            let descriptor = UIFontDescriptor(fontAttributes: [.family: family])
            uiFont = UIFont(descriptor: descriptor, size: 17)
        } else {
            uiFont = UIFont.systemFont(ofSize: 17)
        }
        let ctFont = uiFont as CTFont
        guard let axesArray = CTFontCopyVariationAxes(ctFont) as? [[String: Any]] else {
            return FontInfo(variationAxes: [])
        }
        let axes = axesArray.compactMap { dict -> VariationAxisInfo? in
            guard
                let identifier = dict[kCTFontVariationAxisIdentifierKey as String] as? Int,
                let name = dict[kCTFontVariationAxisNameKey as String] as? String,
                let minValue = dict[kCTFontVariationAxisMinimumValueKey as String] as? CGFloat,
                let maxValue = dict[kCTFontVariationAxisMaximumValueKey as String] as? CGFloat,
                let defaultValue = dict[kCTFontVariationAxisDefaultValueKey as String] as? CGFloat
            else { return nil }
            let tag = tagFromIdentifier(identifier)
            return VariationAxisInfo(tag: tag, identifier: identifier, name: name, minValue: minValue, maxValue: maxValue, defaultValue: defaultValue)
        }
        return FontInfo(variationAxes: axes)
    }

    private static func tagFromIdentifier(_ id: Int) -> String {
        let bytes: [UInt8] = [
            UInt8((id >> 24) & 0xFF),
            UInt8((id >> 16) & 0xFF),
            UInt8((id >> 8) & 0xFF),
            UInt8(id & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

/// Describes a single variation axis of a variable font.
struct VariationAxisInfo {
    let tag: String
    let identifier: Int
    let name: String
    let minValue: CGFloat
    let maxValue: CGFloat
    let defaultValue: CGFloat
}

// MARK: - UIKit Renderer

final class UIKitTextRenderer: Renderer {
    private weak var label: UILabel?
    private var view: TextLeaf

    init(view: TextLeaf) {
        self.view = view
    }

    func mount() -> PlatformView {
        let label = UILabel()
        self.label = label
        applyAttributedString()
        return label
    }

    func update(from newView: any View) {
        guard let text = newView as? TextLeaf, let label else { return }
        let old = view
        view = text

        applyAttributedString()

        let oldFont = old.style.font ?? Font()
        let newFont = text.style.font ?? Font()
        let needsLayout = old.content != text.content
            || old.style.textCase != text.style.textCase
            || old.style.maxLines != text.style.maxLines
            || oldFont.size != newFont.size
            || oldFont.weight != newFont.weight
            || oldFont.family != newFont.family
            || oldFont.italic != newFont.italic
            || oldFont.tracking != newFont.tracking
            || oldFont.height != newFont.height
        if needsLayout { label.superview?.setNeedsLayout() }
    }

    private func applyAttributedString() {
        guard let label else { return }
        let style = view.style
        let forgeFont = style.font ?? Font()
        let align = style.align ?? .leading
        let textCase = style.textCase ?? .plain
        let overflow = style.overflow ?? .ellipsis

        let displayText = textCase.apply(to: view.content)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = align.nsTextAlignment
        paragraphStyle.lineBreakMode = overflow.lineBreakMode
        paragraphStyle.lineSpacing = forgeFont.resolvedLineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: forgeFont.resolvedFont,
            .paragraphStyle: paragraphStyle,
            .kern: forgeFont.tracking,
        ]

        attributes[.foregroundColor] = style.color?.platformColor ?? UIColor.label

        if let decoration = style.decoration {
            if let underline = decoration.underline {
                attributes[.underlineStyle] = underline.style
                if let color = underline.color { attributes[.underlineColor] = color.platformColor }
            }
            if let strikethrough = decoration.strikethrough {
                attributes[.strikethroughStyle] = strikethrough.style
                if let color = strikethrough.color { attributes[.strikethroughColor] = color.platformColor }
            }
            if let shadow = decoration.shadow {
                let nsShadow = NSShadow()
                nsShadow.shadowColor = shadow.color.platformColor
                nsShadow.shadowBlurRadius = shadow.radius
                nsShadow.shadowOffset = CGSize(width: shadow.offset.width, height: shadow.offset.height)
                attributes[.shadow] = nsShadow
            }
        }

        label.attributedText = NSAttributedString(string: displayText, attributes: attributes)
        label.numberOfLines = style.maxLines ?? 0
    }
}

#endif

// MARK: - AppKit

#if canImport(AppKit)
import AppKit

final class AppKitTextRenderer: Renderer {
    private weak var field: NSTextField?

    var content: String {
        didSet {
            guard content != oldValue, let field else { return }
            field.stringValue = content
        }
    }

    init(content: String) {
        self.content = content
    }

    func mount() -> PlatformView {
        let field = NSTextField(labelWithString: content)
        field.alignment = .center
        self.field = field
        return field
    }
}

#endif
