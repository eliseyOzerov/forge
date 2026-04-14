//
//  OverlayStyles.swift
//  ForgeSwift
//
//  Per-presentation-kind styles for the Router's overlay system.
//  Each RoutePresentation case carries one of these; Forge honors
//  the fields it can on the native platform and falls back for the
//  rest.
//
//  Style values are plain Sendable structs, not state-aware — an
//  overlay's visual behavior is fixed for its lifetime, not driven
//  by per-route state. Component-level state (hover, pressed, etc.)
//  lives inside the overlay's *body*, which is a normal Forge view.
//

import Foundation

// MARK: - Barrier

/// The dimmed backdrop behind overlays that need one. Toast, popover,
/// and lightbox don't use a barrier by default; sheets use the native
/// UISheetPresentationController's built-in dimming.
public struct Barrier: Sendable {
    public var color: Color
    /// Blur radius in points. Nil means no blur, color-only dimming.
    public var blur: Double?
    /// Whether tapping the barrier dismisses the overlay.
    public var dismissible: Bool

    public init(
        color: Color = Color(0, 0, 0, 0.4),
        blur: Double? = nil,
        dismissible: Bool = true
    ) {
        self.color = color
        self.blur = blur
        self.dismissible = dismissible
    }

    /// Standard dimmed backdrop. Tap-to-dismiss enabled.
    public static let `default` = Barrier()

    /// No visible backdrop and no dismiss on tap — useful for popovers
    /// and toasts, which sit above content without blocking it.
    public static let transparent = Barrier(
        color: Color(0, 0, 0, 0),
        dismissible: false
    )
}

// MARK: - SheetStyle

/// Bottom sheet with native iOS detents. Maps to
/// UISheetPresentationController.
public struct SheetStyle: Sendable {
    public var detents: [SheetDetent]
    public var grabberVisible: Bool
    /// Bar corner radius in points. Nil leaves the system default.
    public var cornerRadius: Double?
    public var isDismissable: Bool

    public init(
        detents: [SheetDetent] = [.large],
        grabberVisible: Bool = true,
        cornerRadius: Double? = nil,
        isDismissable: Bool = true
    ) {
        self.detents = detents
        self.grabberVisible = grabberVisible
        self.cornerRadius = cornerRadius
        self.isDismissable = isDismissable
    }
}

// MARK: - CoverStyle

/// Opaque full-screen modal. Slides up from the bottom. iOS equivalent
/// of Flutter's CoverRoute — used for self-contained flows that take
/// over the whole screen (camera, onboarding, composer).
public struct CoverStyle: Sendable {
    public var transitionDuration: TimeInterval

    public init(transitionDuration: TimeInterval = 0.3) {
        self.transitionDuration = transitionDuration
    }
}

// MARK: - ModalStyle

/// Centered overlay with a barrier and fade+scale entry. Used for
/// dialogs, confirmations, structured alerts.
public struct ModalStyle: Sendable {
    public var barrier: Barrier
    public var transitionDuration: TimeInterval
    /// Initial scale during the entry transition (typically 0.9).
    public var entryScale: Double
    /// Max width of the modal content. Nil lets content size itself.
    public var maxWidth: Double?

    public init(
        barrier: Barrier = .default,
        transitionDuration: TimeInterval = 0.25,
        entryScale: Double = 0.9,
        maxWidth: Double? = 340
    ) {
        self.barrier = barrier
        self.transitionDuration = transitionDuration
        self.entryScale = entryScale
        self.maxWidth = maxWidth
    }
}

// MARK: - AlertStyle

/// Specialized centered dialog. Alert content conforms to a
/// structured shape (title + message + actions) in its body; this
/// style configures the presentation, not the content.
public struct AlertStyle: Sendable {
    public var barrier: Barrier
    public var transitionDuration: TimeInterval
    public var entryScale: Double
    public var maxWidth: Double?

    public init(
        barrier: Barrier = .default,
        transitionDuration: TimeInterval = 0.25,
        entryScale: Double = 0.9,
        maxWidth: Double? = 270
    ) {
        self.barrier = barrier
        self.transitionDuration = transitionDuration
        self.entryScale = entryScale
        self.maxWidth = maxWidth
    }
}

// MARK: - DrawerStyle

/// Slide-from-edge panel with fixed or auto width. Leading edge by
/// default (nav drawer); trailing / top / bottom for other use cases.
public struct DrawerStyle: Sendable {
    public var edge: Edge
    /// Fixed width for leading/trailing drawers. Nil for auto.
    public var width: Double?
    /// Fixed height for top/bottom drawers. Nil for auto.
    public var height: Double?
    public var barrier: Barrier
    public var transitionDuration: TimeInterval

    public init(
        edge: Edge = .leading,
        width: Double? = 300,
        height: Double? = nil,
        barrier: Barrier = .default,
        transitionDuration: TimeInterval = 0.25
    ) {
        self.edge = edge
        self.width = width
        self.height = height
        self.barrier = barrier
        self.transitionDuration = transitionDuration
    }
}

// MARK: - PopoverStyle

/// Anchored to a rect in screen coordinates, auto-positioned to fit.
/// The anchor is a closure so it can read a RectReporter-tracked rect
/// captured by an upstream view — no tight coupling to a specific
/// widget.
public struct PopoverStyle: @unchecked Sendable {
    /// Resolves the anchor rect in screen coordinates.
    public var anchor: @MainActor () -> Rect

    /// Anchor point on the originating (child) rect.
    public var childAnchor: Alignment
    /// Anchor point on the popover that mates to `childAnchor`.
    public var popoverAnchor: Alignment

    /// Gap between popover and anchor edge.
    public var margin: Padding
    /// Inset from the screen edges — popover repositions to stay
    /// within this padded area.
    public var screenPadding: Padding

    public var transitionDuration: TimeInterval
    public var barrier: Barrier

    public init(
        anchor: @escaping @MainActor () -> Rect,
        childAnchor: Alignment = .bottomLeft,
        popoverAnchor: Alignment = .topLeft,
        margin: Padding = Padding(all: 4),
        screenPadding: Padding = Padding(all: 8),
        transitionDuration: TimeInterval = 0.15,
        barrier: Barrier = .transparent
    ) {
        self.anchor = anchor
        self.childAnchor = childAnchor
        self.popoverAnchor = popoverAnchor
        self.margin = margin
        self.screenPadding = screenPadding
        self.transitionDuration = transitionDuration
        self.barrier = barrier
    }
}

// MARK: - ToastStyle

/// Self-dismissing, non-blocking notification sliding from top or
/// bottom. No barrier — the rest of the app stays interactive.
public struct ToastStyle: Sendable {
    /// Only .top and .bottom are meaningful for v1.
    public var position: Edge
    public var displayDuration: TimeInterval
    public var padding: Padding
    public var transitionDuration: TimeInterval

    public init(
        position: Edge = .bottom,
        displayDuration: TimeInterval = 3.0,
        padding: Padding = Padding(all: 16),
        transitionDuration: TimeInterval = 0.2
    ) {
        self.position = position
        self.displayDuration = displayDuration
        self.padding = padding
        self.transitionDuration = transitionDuration
    }
}

// MARK: - LightboxStyle

/// Full-screen media viewer with opaque background. Like cover but
/// with a configurable background colour (typically black).
public struct LightboxStyle: Sendable {
    public var background: Color
    public var transitionDuration: TimeInterval

    public init(
        background: Color = Color(0, 0, 0),
        transitionDuration: TimeInterval = 0.3
    ) {
        self.background = background
        self.transitionDuration = transitionDuration
    }
}

// MARK: - CoachMarkStyle

/// Multi-step guided tour. Each step highlights a target rect with
/// a hole-punched overlay and shows coaching content next to it.
public struct CoachMarkStyle: @unchecked Sendable {
    public var steps: [CoachMarkStep]
    /// Covers the whole screen except the current step's cutout.
    public var barrier: Barrier
    /// Called when the user finishes or dismisses the tour.
    public var onComplete: (@MainActor () -> Void)?

    public init(
        steps: [CoachMarkStep],
        barrier: Barrier = Barrier(color: Color(0, 0, 0, 0.6)),
        onComplete: (@MainActor () -> Void)? = nil
    ) {
        self.steps = steps
        self.barrier = barrier
        self.onComplete = onComplete
    }
}

public struct CoachMarkStep: @unchecked Sendable {
    /// Rect in screen coordinates for the cutout highlight.
    public var target: @MainActor () -> Rect
    /// Corner radius of the cutout.
    public var cornerRadius: Double
    /// Extra padding around the target rect for the cutout.
    public var padding: Padding
    /// View shown alongside the cutout (typically a Forge composition
    /// with a title + body + "Next" button).
    public var content: @MainActor () -> any View

    public init(
        target: @escaping @MainActor () -> Rect,
        cornerRadius: Double = 8,
        padding: Padding = Padding(all: 4),
        @ChildBuilder content: @escaping @MainActor () -> any View
    ) {
        self.target = target
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }
}

// MARK: - ContextMenuStyle

/// iOS-style context menu: a scaled preview of the source view plus
/// a menu list. Anchored to a rect in screen coordinates.
public struct ContextMenuStyle: @unchecked Sendable {
    public var anchor: @MainActor () -> Rect
    /// Scaled-up preview view rendered above the menu.
    public var preview: @MainActor () -> any View
    /// Scale factor applied to the preview (typically 1.1).
    public var previewScale: Double
    public var barrier: Barrier
    public var transitionDuration: TimeInterval

    public init(
        anchor: @escaping @MainActor () -> Rect,
        @ChildBuilder preview: @escaping @MainActor () -> any View,
        previewScale: Double = 1.1,
        barrier: Barrier = .default,
        transitionDuration: TimeInterval = 0.25
    ) {
        self.anchor = anchor
        self.preview = preview
        self.previewScale = previewScale
        self.barrier = barrier
        self.transitionDuration = transitionDuration
    }
}
