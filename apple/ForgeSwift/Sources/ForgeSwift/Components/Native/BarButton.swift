//
//  BarButton.swift
//  ForgeSwift
//
//  Native-backed bar button — a LeafView that mounts a real UIButton
//  with UIKit's configuration, so when it ends up inside a
//  UINavigationController's bar (or a UIToolbar), the OS renders it
//  with the standard bar-button treatment (Liquid Glass morph,
//  vibrancy, container grouping) instead of the "custom view" path
//  that bypasses all of that.
//
//  The Router's hosting controller recognises `BarButton` in a
//  NavigationItem's leading/trailing slot and produces a true
//  `UIBarButtonItem(primaryAction:)` from it — that's what
//  participates in the bar's glass container. Outside a bar (inside
//  a normal Forge view tree), `BarButton` renders as a configured
//  UIButton and works as an ordinary tappable control.
//
//  Why a Native folder: this file is a deliberate bridge — the
//  component only makes sense in a UIKit context and its shape
//  mirrors a UIKit type one-for-one. Keeping these separate from the
//  portable primitives under `Components/Content` / `Layout` /
//  `Input` makes the platform coupling obvious at a glance.
//

#if canImport(UIKit)
import UIKit

// MARK: - BarButton

/// A button intended for navigation bars and toolbars. Declares its
/// content (label, icon, role) as data; the rendering is deferred to
/// the enclosing container — native bar-button treatment when placed
/// in a nav bar or toolbar, a styled UIButton otherwise.
///
///     BarButton(icon: "plus") { /* add action */ }
///     BarButton(label: "Save", style: .prominent) { save() }
///     BarButton(icon: "trash", role: .destructive) { delete() }
public struct BarButton: LeafView {
    public let label: String?
    public let icon: String?
    public let style: BarButtonStyle
    public let role: BarButtonRole
    public let isEnabled: Bool
    public let onTap: @MainActor () -> Void

    public init(
        label: String? = nil,
        icon: String? = nil,
        style: BarButtonStyle = .plain,
        role: BarButtonRole = .regular,
        isEnabled: Bool = true,
        onTap: @escaping @MainActor () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.style = style
        self.role = role
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    public func makeRenderer() -> Renderer {
        BarButtonRenderer(view: self)
    }
}

// MARK: - BarButtonStyle

/// Rendering style for a `BarButton`. Maps to iOS 26's
/// `UIButton.Configuration` variants; the OS supplies the Liquid
/// Glass surface for `plain` and applies extra emphasis for `prominent`.
public enum BarButtonStyle: Sendable, Equatable {
    /// Standard bar button — icon/label on transparent glass.
    case plain
    /// Filled, tinted with the container's accent color.
    case prominent
}

/// Semantic role for the action. `destructive` renders with the
/// system red tint and receives the matching accessibility trait.
public enum BarButtonRole: Sendable, Equatable {
    case regular
    case destructive
}

// MARK: - UIBarButtonItem bridging

public extension BarButton {
    /// Produce a native `UIBarButtonItem` from this declaration. Used
    /// by the Router when a `BarButton` appears in a navigation item's
    /// leading/trailing slot — lets the bar render the button with
    /// its proper native treatment (glass container, morph, vibrancy).
    @MainActor
    func makeBarButtonItem() -> UIBarButtonItem {
        let image = icon.flatMap { UIImage(systemName: $0) }
        let tap = onTap
        var attributes: UIAction.Attributes = []
        if role == .destructive { attributes.insert(.destructive) }
        if !isEnabled { attributes.insert(.disabled) }
        let action = UIAction(
            title: label ?? "",
            image: image,
            attributes: attributes,
            handler: { _ in tap() }
        )
        let item = UIBarButtonItem(primaryAction: action)
        item.style = style == .prominent ? .done : .plain
        item.isEnabled = isEnabled
        return item
    }
}

// MARK: - Renderer (used when BarButton is NOT in a bar slot)

final class BarButtonRenderer: Renderer {
    private weak var button: UIButton?

    var view: BarButton {
        didSet {
            guard let button else { return }
            button.configuration = configuration(for: view)
            button.isEnabled = view.isEnabled
            rewireAction(on: button)
        }
    }

    init(view: BarButton) {
        self.view = view
    }

    func update(from view: any View) {
        guard let barButton = view as? BarButton else { return }
        self.view = barButton
    }

    func mount() -> PlatformView {
        let button = UIButton(configuration: configuration(for: view))
        self.button = button
        button.isEnabled = view.isEnabled
        wireAction(on: button)
        return button
    }

    private func configuration(for view: BarButton) -> UIButton.Configuration {
        var config: UIButton.Configuration
        switch view.style {
        case .plain:     config = .plain()
        case .prominent: config = .borderedProminent()
        }
        config.title = view.label
        if let icon = view.icon {
            config.image = UIImage(systemName: icon)
        }
        if view.role == .destructive {
            config.baseForegroundColor = .systemRed
            if view.style == .prominent {
                config.baseBackgroundColor = .systemRed
            }
        }
        return config
    }

    private func wireAction(on button: UIButton) {
        let tap = view.onTap
        button.addAction(UIAction { _ in tap() }, for: .primaryActionTriggered)
    }

    private func rewireAction(on button: UIButton) {
        // Swap the action closure so re-renders pick up the new onTap
        // capture. Cheapest way is to clear and re-add.
        button.removeTarget(nil, action: nil, for: .primaryActionTriggered)
        for action in button.actions(forTarget: nil, forControlEvent: .primaryActionTriggered) ?? [] {
            button.removeAction(identifiedBy: .init(action), for: .primaryActionTriggered)
        }
        // UIKit doesn't offer a clean "remove all closure actions"
        // API; in practice an extra registration is benign because
        // only the most recent closure captures the current onTap,
        // but we still try to keep it clean here.
        wireAction(on: button)
    }
}

#endif
