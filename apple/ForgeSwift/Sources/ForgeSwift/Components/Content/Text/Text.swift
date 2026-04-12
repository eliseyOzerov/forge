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
