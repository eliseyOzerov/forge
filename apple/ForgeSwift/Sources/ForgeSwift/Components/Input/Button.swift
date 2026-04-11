//
//  Button.swift
//  ForgeSwift
//
//  First input leaf. A plain title + tap handler. Mounts to UIButton
//  on UIKit via UIAction (iOS 14+), so no target/selector boilerplate.
//

#if canImport(UIKit)
import UIKit

public struct Button: LeafView {
    public let title: String
    public let onTap: @MainActor () -> Void

    public init(_ title: String, onTap: @escaping @MainActor () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public func makeRenderer() -> Renderer {
        ButtonRenderer(title: title, onTap: onTap)
    }
}

@MainActor public final class ButtonRenderer: Renderer {
    let title: String
    let onTap: @MainActor () -> Void

    init(title: String, onTap: @escaping @MainActor () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public func mount() -> PlatformView {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        let handler = onTap
        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        return button
    }
}

#endif
