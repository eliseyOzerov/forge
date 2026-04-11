//
//  Text.swift
//  SwiftKit
//
//  First leaf view end-to-end. Proves the protocol shape produces
//  a visible pixel.
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
        label.text = content
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
        #elseif canImport(AppKit)
        let label = NSTextField(labelWithString: content)
        label.alignment = .center
        return label
        #endif
    }
}
