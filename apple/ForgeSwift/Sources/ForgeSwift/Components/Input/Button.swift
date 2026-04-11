//
//  Button.swift
//  ForgeSwift
//
//  First input leaf. A plain title + tap handler. Mounts to UIButton
//  on UIKit via UIAction (iOS 14+), so no target/selector boilerplate.
//
//  The UIAction is identified by a stable identifier so update() can
//  replace it in place when the closure's captured state changes.
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

public final class ButtonRenderer: Renderer {
    let title: String
    let onTap: @MainActor () -> Void

    private static let tapActionId = UIAction.Identifier("forge.button.onTap")

    init(title: String, onTap: @escaping @MainActor () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public func mount() -> PlatformView {
        let button = UIButton(type: .system)
        apply(to: button)
        return button
    }

    public func update(_ platformView: PlatformView) {
        guard let button = platformView as? UIButton else { return }
        apply(to: button)
    }

    private func apply(to button: UIButton) {
        button.setTitle(title, for: .normal)
        button.removeAction(identifiedBy: Self.tapActionId, for: .touchUpInside)
        let handler = onTap
        button.addAction(
            UIAction(identifier: Self.tapActionId) { _ in handler() },
            for: .touchUpInside
        )
    }
}

#endif
