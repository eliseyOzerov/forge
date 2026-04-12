#if canImport(UIKit)
import UIKit
import CoreText
#elseif canImport(AppKit)
import AppKit
import CoreText
#endif

public struct TextStyle: Sendable {
    public var font: Font
    public var color: PlatformColor?
    public var maxLines: Int?
    public var align: TextAlign
    public var textCase: TextCase
    public var overflow: TextOverflow
    public var decoration: TextDecoration?

    public init(
        font: Font = Font(),
        color: PlatformColor? = nil,
        maxLines: Int? = nil,
        align: TextAlign = .leading,
        textCase: TextCase = .none,
        overflow: TextOverflow = .ellipsis,
        decoration: TextDecoration? = nil
    ) {
        self.font = font
        self.color = color
        self.maxLines = maxLines
        self.align = align
        self.textCase = textCase
        self.overflow = overflow
        self.decoration = decoration
    }
}

// MARK: - FontConfig

public struct Font: Sendable {
    public var family: String?
    public var size: CGFloat
    public var height: CGFloat
    public var tracking: CGFloat
    public var weight: CGFloat
    public var italic: Bool
    public var features: FontFeatures?

    public init(
        family: String? = nil,
        size: CGFloat = 17,
        lineHeight: CGFloat = 1.2,
        tracking: CGFloat = 0,
        weight: CGFloat = 400,
        italic: Bool = false,
        features: FontFeatures? = nil
    ) {
        self.family = family
        self.size = size
        self.height = lineHeight
        self.tracking = tracking
        self.weight = weight
        self.italic = italic
        self.features = features
    }

    public var resolvedLineSpacing: CGFloat {
        max(0, (height - 1.0) * size)
    }

    #if canImport(UIKit)
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
        var variations: [Int: CGFloat] = [:]

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

    private static func uiFontWeight(from weight: CGFloat) -> UIFont.Weight {
        let stops: [(CGFloat, CGFloat)] = [
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
    #endif

    private static func tagToNumber(_ tag: String) -> Int {
        let bytes = Array(tag.utf8)
        guard bytes.count == 4 else { return 0 }
        return Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
    }
}

// MARK: - FontFeatures

public struct FontFeatures: Sendable {
    public var stylisticSets: Set<Int>
    public var alternates: [Int: Int]
    public var axes: [FontAxis: CGFloat]
    public var rawTags: Set<String>

    public init(
        stylisticSets: Set<Int> = [],
        alternates: [Int: Int] = [:],
        axes: [FontAxis: CGFloat] = [:],
        rawTags: Set<String> = []
    ) {
        self.stylisticSets = stylisticSets
        self.alternates = alternates
        self.axes = axes
        self.rawTags = rawTags
    }
}

// MARK: - FontAxis

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

// MARK: - FontInfo

#if canImport(UIKit)
struct FontInfo {
    let variationAxes: [VariationAxisInfo]

    var hasWeightAxis: Bool { variationAxes.contains { $0.tag == "wght" } }

    static func query(family: String?) -> FontInfo {
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

struct VariationAxisInfo {
    let tag: String
    let identifier: Int
    let name: String
    let minValue: CGFloat
    let maxValue: CGFloat
    let defaultValue: CGFloat
}
#endif

// MARK: - TextAlign

public enum TextAlign: String, Sendable {
    case leading
    case trailing
    case center
    case justify

    #if canImport(UIKit)
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: .natural
        case .trailing: .right
        case .center: .center
        case .justify: .justified
        }
    }
    #endif
}

// MARK: - TextOverflow

public enum TextOverflow: String, Sendable {
    case clip
    case fade
    case ellipsis

    #if canImport(UIKit)
    var lineBreakMode: NSLineBreakMode {
        switch self {
        case .clip: .byClipping
        case .fade: .byClipping
        case .ellipsis: .byTruncatingTail
        }
    }
    #endif
}

// MARK: - TextCase

public enum TextCase: String, Sendable {
    case none
    case uppercase
    case lowercase
    case capitalize

    public func apply(to text: String) -> String {
        switch self {
        case .none: text
        case .uppercase: text.uppercased()
        case .lowercase: text.lowercased()
        case .capitalize: text.prefix(1).uppercased() + text.dropFirst()
        }
    }
}

// MARK: - TextDecoration

public struct TextDecoration: Sendable {
    public var line: TextLineConfig?
    public var shadow: ShadowConfig?

    public init(line: TextLineConfig? = nil, shadow: ShadowConfig? = nil) {
        self.line = line
        self.shadow = shadow
    }
}

public struct TextLineConfig: Sendable {
    public var color: PlatformColor?
    public var position: TextLinePosition
    public var style: Int

    public init(
        color: PlatformColor? = nil,
        position: TextLinePosition = .underline,
        style: Int = 0x01
    ) {
        self.color = color
        self.position = position
        self.style = style
    }

    public static let single = 0x01
    public static let double = 0x09
    public static let thick = 0x02
}

public enum TextLinePosition: String, Sendable {
    case underline
    case strikethrough
}

public struct ShadowConfig: Sendable {
    public var color: PlatformColor
    public var radius: CGFloat
    public var offset: CGSize

    public init(
        color: PlatformColor = PlatformColor.black.withAlphaComponent(0.33),
        radius: CGFloat = 1,
        offset: CGSize = CGSize(width: 0, height: 1)
    ) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
}

public struct Text: LeafView {
    public let content: String
    public let style: TextStyle

    public init(_ content: String, style: TextStyle = TextStyle()) {
        self.content = content
        self.style = style
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        return UIKitTextRenderer(content: content, style: style)
        #elseif canImport(AppKit)
        return AppKitTextRenderer(content: content)
        #endif
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

final class UIKitTextRenderer: Renderer {
    let content: String
    let style: TextStyle

    init(content: String, style: TextStyle) {
        self.content = content
        self.style = style
    }

    func mount() -> PlatformView {
        let label = UILabel()
        apply(to: label)
        return label
    }

    func update(_ platformView: PlatformView) {
        guard let label = platformView as? UILabel else { return }
        apply(to: label)
    }

    private func apply(to label: UILabel) {
        let displayText = style.textCase.apply(to: content)
        let font = style.font.resolvedFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = style.align.nsTextAlignment
        paragraphStyle.lineBreakMode = style.overflow.lineBreakMode
        paragraphStyle.lineSpacing = style.font.resolvedLineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .kern: style.font.tracking,
        ]

        attributes[.foregroundColor] = style.color ?? UIColor.label

        if let decoration = style.decoration {
            if let line = decoration.line {
                switch line.position {
                case .underline:
                    attributes[.underlineStyle] = line.style
                    if let color = line.color { attributes[.underlineColor] = color }
                case .strikethrough:
                    attributes[.strikethroughStyle] = line.style
                    if let color = line.color { attributes[.strikethroughColor] = color }
                }
            }
            if let shadow = decoration.shadow {
                let nsShadow = NSShadow()
                nsShadow.shadowColor = shadow.color
                nsShadow.shadowBlurRadius = shadow.radius
                nsShadow.shadowOffset = shadow.offset
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
    let content: String

    init(content: String) {
        self.content = content
    }

    func mount() -> PlatformView {
        let field = NSTextField(labelWithString: content)
        field.alignment = .center
        return field
    }

    func update(_ platformView: PlatformView) {
        guard let field = platformView as? NSTextField else { return }
        field.stringValue = content
    }
}

#endif
