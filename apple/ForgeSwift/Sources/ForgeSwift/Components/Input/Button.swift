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
        // UIButton implicitly cross-fades its titleLabel on setTitle
        // since iOS 15. When our rebuild lands mid-way through the
        // button's own highlighted→normal state animation, the two
        // stack and the label ends up fading from 0 to 1 over ~0.5s.
        // Suppressing implicit animations + forcing immediate layout
        // makes the title change instant.
        UIView.performWithoutAnimation {
            button.setTitle(title, for: .normal)
            button.removeAction(identifiedBy: Self.tapActionId, for: .touchUpInside)
            let handler = onTap
            button.addAction(
                UIAction(identifier: Self.tapActionId) { _ in handler() },
                for: .touchUpInside
            )
            button.layoutIfNeeded()
        }
    }
}

#endif
