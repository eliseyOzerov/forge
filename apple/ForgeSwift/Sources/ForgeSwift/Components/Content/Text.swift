//
//  Text.swift
//  ForgeSwift
//
//  The Text View is cross-platform; its backing Renderer is not.
//  makeRenderer() is the single place that branches on platform.
//  Each renderer class is fully one ecosystem's code (UIKit or
//  AppKit) with no `#if` inside its method bodies — the conditional
//  compilation lives at the file-section level, so a reader can look
//  at UIKitTextRenderer and see only UIKit, at AppKitTextRenderer
//  and see only AppKit.
//

public struct Text: LeafView {
    public let content: String

    public init(_ content: String) {
        self.content = content
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        return UIKitTextRenderer(content: content)
        #elseif canImport(AppKit)
        return AppKitTextRenderer(content: content)
        #endif
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

public final class UIKitTextRenderer: Renderer {
    let content: String

    init(content: String) {
        self.content = content
    }

    public func mount() -> PlatformView {
        let label = UILabel()
        apply(to: label)
        return label
    }

    public func update(_ platformView: PlatformView) {
        guard let label = platformView as? UILabel else { return }
        apply(to: label)
    }

    private func apply(to label: UILabel) {
        label.text = content
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
    }
}

#endif

// MARK: - AppKit

#if canImport(AppKit)
import AppKit

public final class AppKitTextRenderer: Renderer {
    let content: String

    init(content: String) {
        self.content = content
    }

    public func mount() -> PlatformView {
        let field = NSTextField(labelWithString: content)
        field.alignment = .center
        return field
    }

    public func update(_ platformView: PlatformView) {
        guard let field = platformView as? NSTextField else { return }
        field.stringValue = content
    }
}

#endif
