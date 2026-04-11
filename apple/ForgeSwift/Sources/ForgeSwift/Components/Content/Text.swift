//
//  Text.swift
//  ForgeSwift
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct Text: LeafView {
    public let content: String

    public init(_ content: String) {
        self.content = content
    }

    public func makeRenderer() -> Renderer {
        TextRenderer(content: content)
    }
}

@MainActor public final class TextRenderer: Renderer {
    let content: String

    init(content: String) {
        self.content = content
    }

    public func mount() -> PlatformView {
        #if canImport(UIKit)
        let label = UILabel()
        apply(to: label)
        return label
        #elseif canImport(AppKit)
        let label = NSTextField(labelWithString: content)
        label.alignment = .center
        return label
        #endif
    }

    public func update(_ platformView: PlatformView) {
        #if canImport(UIKit)
        guard let label = platformView as? UILabel else { return }
        apply(to: label)
        #elseif canImport(AppKit)
        guard let label = platformView as? NSTextField else { return }
        label.stringValue = content
        #endif
    }

    #if canImport(UIKit)
    private func apply(to label: UILabel) {
        label.text = content
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
    }
    #endif
}
