//
//  OverlayPresentation.swift
//  ForgeSwift
//
//  Custom UIPresentationControllers + animators for Forge's overlay
//  route kinds that don't map to a native UIKit presentation style
//  (modal, alert, drawer, popover, context menu, coach mark).
//
//  Each overlay family has its own UIPresentationController subclass
//  that lays out the presented view and manages a BarrierView. A small
//  set of reusable animators (fade+scale, slide-from-edge) covers the
//  transition behavior across families.
//

#if canImport(UIKit)
import UIKit

// MARK: - BarrierView

/// The dimmed/blurred backdrop mounted behind an overlay. Responds to
/// taps when the Barrier allows dismissal.
final class BarrierView: UIView {
    private let barrier: Barrier
    private let onTap: () -> Void
    private var blurView: UIVisualEffectView?

    init(barrier: Barrier, onTap: @escaping () -> Void) {
        self.barrier = barrier
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = barrier.color.platformColor
        if let blur = barrier.blur, blur > 0 {
            let effect = UIBlurEffect(style: .systemMaterial)
            let view = UIVisualEffectView(effect: effect)
            view.frame = bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(view)
            blurView = view
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleTap() {
        guard barrier.dismissible else { return }
        onTap()
    }
}

// MARK: - Animators

/// Fade + scale for centered content (modal, alert, popover). Initial
/// scale is read from the presented controller's transition config
/// via the `scale` closure so each presentation can specify its own.
final class FadeScaleAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    let initialScale: Double
    let isPresenting: Bool

    init(duration: TimeInterval, initialScale: Double, isPresenting: Bool) {
        self.duration = duration
        self.initialScale = initialScale
        self.isPresenting = isPresenting
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        if isPresenting {
            guard let toView = ctx.view(forKey: .to) else { return ctx.completeTransition(false) }
            container.addSubview(toView)
            toView.alpha = 0
            toView.transform = CGAffineTransform(scaleX: initialScale, y: initialScale)
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
                toView.alpha = 1
                toView.transform = .identity
            }, completion: { finished in
                ctx.completeTransition(finished)
            })
        } else {
            guard let fromView = ctx.view(forKey: .from) else { return ctx.completeTransition(false) }
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn], animations: {
                fromView.alpha = 0
                fromView.transform = CGAffineTransform(scaleX: self.initialScale, y: self.initialScale)
            }, completion: { finished in
                fromView.removeFromSuperview()
                ctx.completeTransition(finished)
            })
        }
    }
}

/// Slide in from a given edge. Used for drawers.
final class SlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    let edge: Edge
    let isPresenting: Bool

    init(duration: TimeInterval, edge: Edge, isPresenting: Bool) {
        self.duration = duration
        self.edge = edge
        self.isPresenting = isPresenting
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        let container = ctx.containerView
        let targetFrameKey: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        guard let vc = ctx.viewController(forKey: targetFrameKey),
              let view = ctx.view(forKey: isPresenting ? .to : .from) else {
            return ctx.completeTransition(false)
        }

        let finalFrame = ctx.finalFrame(for: vc)
        let offscreen = Self.offscreenFrame(finalFrame: finalFrame, container: container.bounds, edge: edge)

        if isPresenting {
            container.addSubview(view)
            view.frame = offscreen
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
                view.frame = finalFrame
            }, completion: { finished in
                ctx.completeTransition(finished)
            })
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn], animations: {
                view.frame = offscreen
            }, completion: { finished in
                view.removeFromSuperview()
                ctx.completeTransition(finished)
            })
        }
    }

    private static func offscreenFrame(finalFrame: CGRect, container: CGRect, edge: Edge) -> CGRect {
        var f = finalFrame
        switch edge {
        case .top: f.origin.y = -finalFrame.height
        case .bottom: f.origin.y = container.height
        case .leading: f.origin.x = -finalFrame.width
        case .trailing: f.origin.x = container.width
        }
        return f
    }
}

// MARK: - CenteredPresentationController

/// Shared presentation controller for modal + alert: centered content
/// with barrier, content sized to fit with an optional maxWidth.
final class CenteredPresentationController: UIPresentationController {
    private let barrier: Barrier
    private let maxWidth: Double?
    private var barrierView: BarrierView?

    init(
        presented: UIViewController,
        presenting: UIViewController?,
        barrier: Barrier,
        maxWidth: Double?
    ) {
        self.barrier = barrier
        self.maxWidth = maxWidth
        super.init(presentedViewController: presented, presenting: presenting)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        let width = min(container.bounds.width - 32, maxWidth ?? .infinity)
        let fitSize = CGSize(width: width, height: container.bounds.height - 64)
        let size = presentedView?.systemLayoutSizeFitting(
            fitSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ) ?? CGSize(width: width, height: 200)
        let h = min(size.height, container.bounds.height - 64)
        return CGRect(
            x: (container.bounds.width - width) / 2,
            y: (container.bounds.height - h) / 2,
            width: width,
            height: h
        )
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        let bv = BarrierView(barrier: barrier) { [weak self] in
            self?.presentedViewController.dismiss(animated: true)
        }
        bv.frame = container.bounds
        bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bv.alpha = 0
        container.addSubview(bv)
        barrierView = bv

        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 1 })
        } else {
            bv.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        guard let bv = barrierView else { return }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 0 })
        } else {
            bv.alpha = 0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { barrierView?.removeFromSuperview() }
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - DrawerPresentationController

final class DrawerPresentationController: UIPresentationController {
    private let barrier: Barrier
    private let edge: Edge
    private let fixedWidth: Double?
    private let fixedHeight: Double?
    private var barrierView: BarrierView?

    init(
        presented: UIViewController,
        presenting: UIViewController?,
        style: DrawerStyle
    ) {
        self.barrier = style.barrier
        self.edge = style.edge
        self.fixedWidth = style.width
        self.fixedHeight = style.height
        super.init(presentedViewController: presented, presenting: presenting)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        let b = container.bounds
        switch edge {
        case .leading:
            let w = fixedWidth ?? 300
            return CGRect(x: 0, y: 0, width: w, height: b.height)
        case .trailing:
            let w = fixedWidth ?? 300
            return CGRect(x: b.width - w, y: 0, width: w, height: b.height)
        case .top:
            let h = fixedHeight ?? 300
            return CGRect(x: 0, y: 0, width: b.width, height: h)
        case .bottom:
            let h = fixedHeight ?? 300
            return CGRect(x: 0, y: b.height - h, width: b.width, height: h)
        }
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        let bv = BarrierView(barrier: barrier) { [weak self] in
            self?.presentedViewController.dismiss(animated: true)
        }
        bv.frame = container.bounds
        bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bv.alpha = 0
        container.addSubview(bv)
        barrierView = bv

        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 1 })
        } else {
            bv.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        guard let bv = barrierView else { return }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 0 })
        } else {
            bv.alpha = 0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { barrierView?.removeFromSuperview() }
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - PopoverPresentationController

/// Anchored popover with auto-positioning. Walks a small list of
/// fallback anchor pairs to find a fit inside the screen (minus
/// screenPadding); if no pair fits, falls back to the configured one
/// clamped into the screen.
final class PopoverPresentationController: UIPresentationController {
    private let style: PopoverStyle
    private var barrierView: BarrierView?

    init(
        presented: UIViewController,
        presenting: UIViewController?,
        style: PopoverStyle
    ) {
        self.style = style
        super.init(presentedViewController: presented, presenting: presenting)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView, let view = presentedView else { return .zero }
        let anchorRect = style.anchor().cgRect
        let targetSize = view.systemLayoutSizeFitting(
            container.bounds.size,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let size = targetSize == .zero ? CGSize(width: 240, height: 120) : targetSize

        let bounds = container.bounds.inset(by: UIEdgeInsets(
            top: style.screenPadding.top,
            left: style.screenPadding.leading,
            bottom: style.screenPadding.bottom,
            right: style.screenPadding.trailing
        ))

        // Try preferred, then flipped alternatives.
        let trials: [(Alignment, Alignment)] = [
            (style.childAnchor, style.popoverAnchor),
            (style.childAnchor.flippedVertical, style.popoverAnchor.flippedVertical),
            (style.childAnchor.flippedHorizontal, style.popoverAnchor.flippedHorizontal),
            (style.childAnchor.flippedBoth, style.popoverAnchor.flippedBoth),
        ]
        for (childA, popA) in trials {
            let origin = Self.origin(
                anchor: anchorRect,
                size: size,
                childAnchor: childA,
                popoverAnchor: popA,
                margin: style.margin
            )
            let frame = CGRect(origin: origin, size: size)
            if bounds.contains(frame) { return frame }
        }
        // Fallback: clamp preferred to bounds.
        let origin = Self.origin(
            anchor: anchorRect,
            size: size,
            childAnchor: style.childAnchor,
            popoverAnchor: style.popoverAnchor,
            margin: style.margin
        )
        var frame = CGRect(origin: origin, size: size)
        frame.origin.x = min(max(frame.origin.x, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, bounds.minY), bounds.maxY - frame.height)
        return frame
    }

    private static func origin(
        anchor: CGRect,
        size: CGSize,
        childAnchor: Alignment,
        popoverAnchor: Alignment,
        margin: Padding
    ) -> CGPoint {
        let anchorPoint = CGPoint(
            x: anchor.minX + anchor.width * childAnchor.fractionalX,
            y: anchor.minY + anchor.height * childAnchor.fractionalY
        )
        let popoverOffsetX = size.width * popoverAnchor.fractionalX
        let popoverOffsetY = size.height * popoverAnchor.fractionalY
        // Gap along primary axis (vertical if child is top/bottom, horizontal otherwise).
        let gapY = childAnchor.fractionalY < 0.5 ? -margin.top : margin.bottom
        let gapX = childAnchor.fractionalX < 0.5 ? -margin.leading : margin.trailing
        return CGPoint(
            x: anchorPoint.x - popoverOffsetX + gapX,
            y: anchorPoint.y - popoverOffsetY + gapY
        )
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        let bv = BarrierView(barrier: style.barrier) { [weak self] in
            self?.presentedViewController.dismiss(animated: true)
        }
        bv.frame = container.bounds
        bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bv.alpha = 0
        container.addSubview(bv)
        barrierView = bv
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 1 })
        } else {
            bv.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        guard let bv = barrierView else { return }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 0 })
        } else {
            bv.alpha = 0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { barrierView?.removeFromSuperview() }
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - Alignment helpers

private extension Alignment {
    // Alignment is stored as Vec2 in -1...1. Map to 0...1 for anchor math.
    var fractionalX: CGFloat { CGFloat((x + 1) / 2) }
    var fractionalY: CGFloat { CGFloat((y + 1) / 2) }

    var flippedVertical: Alignment { Alignment(x, -y) }
    var flippedHorizontal: Alignment { Alignment(-x, y) }
    var flippedBoth: Alignment { Alignment(-x, -y) }
}


// MARK: - ContextMenuPresentationController

/// Anchored context menu: preview (scaled) above/below the anchor,
/// action list under the preview. The presented VC's view contains
/// the full stacked content — this controller just positions it.
final class ContextMenuPresentationController: UIPresentationController {
    private let style: ContextMenuStyle
    private var barrierView: BarrierView?

    init(
        presented: UIViewController,
        presenting: UIViewController?,
        style: ContextMenuStyle
    ) {
        self.style = style
        super.init(presentedViewController: presented, presenting: presenting)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView, let view = presentedView else { return .zero }
        let anchor = style.anchor().cgRect
        let size = view.systemLayoutSizeFitting(
            container.bounds.size,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let resolved = size == .zero ? CGSize(width: 240, height: 240) : size
        // Center horizontally on the anchor, prefer below.
        let x = max(16, min(container.bounds.width - resolved.width - 16, anchor.midX - resolved.width / 2))
        let belowY = anchor.maxY + 8
        let aboveY = anchor.minY - resolved.height - 8
        let y = (belowY + resolved.height) < container.bounds.height - 16 ? belowY : max(16, aboveY)
        return CGRect(x: x, y: y, width: resolved.width, height: resolved.height)
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        let bv = BarrierView(barrier: style.barrier) { [weak self] in
            self?.presentedViewController.dismiss(animated: true)
        }
        bv.frame = container.bounds
        bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bv.alpha = 0
        container.addSubview(bv)
        barrierView = bv
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 1 })
        } else {
            bv.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        guard let bv = barrierView else { return }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in bv.alpha = 0 })
        } else {
            bv.alpha = 0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { barrierView?.removeFromSuperview() }
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - CoachMarkPresentationController

/// Full-screen hole-punched barrier. Each step cuts out a rect + padding
/// + corner radius around its target and places the step content near
/// the cutout. Advances on barrier tap.
final class CoachMarkPresentationController: UIPresentationController {
    private let style: CoachMarkStyle
    private var cutoutLayer: CAShapeLayer?
    private var overlayView: CoachMarkOverlayView?
    private var currentStep: Int = 0

    init(
        presented: UIViewController,
        presenting: UIViewController?,
        style: CoachMarkStyle
    ) {
        self.style = style
        super.init(presentedViewController: presented, presenting: presenting)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        let overlay = CoachMarkOverlayView(
            barrier: style.barrier,
            onTap: { [weak self] in self?.advance() }
        )
        overlay.frame = container.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.alpha = 0
        container.insertSubview(overlay, at: 0)
        overlayView = overlay
        updateCutout()

        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in overlay.alpha = 1 })
        } else {
            overlay.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        guard let overlay = overlayView else { return }
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in overlay.alpha = 0 })
        } else {
            overlay.alpha = 0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { overlayView?.removeFromSuperview() }
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        updateCutout()
    }

    private func advance() {
        currentStep += 1
        if currentStep >= style.steps.count {
            style.onComplete?()
            presentedViewController.dismiss(animated: true)
        } else {
            updateCutout()
        }
    }

    private func updateCutout() {
        guard let overlay = overlayView, currentStep < style.steps.count else { return }
        let step = style.steps[currentStep]
        let r = step.target()
        let expandedX = r.x - step.padding.leading
        let expandedY = r.y - step.padding.top
        let expandedW = r.width + step.padding.leading + step.padding.trailing
        let expandedH = r.height + step.padding.top + step.padding.bottom
        let expanded = CGRect(x: expandedX, y: expandedY, width: expandedW, height: expandedH)
        overlay.setCutout(rect: expanded, cornerRadius: step.cornerRadius)
    }
}

final class CoachMarkOverlayView: UIView {
    private let barrier: Barrier
    private let onTap: () -> Void
    private let maskLayer = CAShapeLayer()

    init(barrier: Barrier, onTap: @escaping () -> Void) {
        self.barrier = barrier
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = barrier.color.platformColor
        layer.mask = maskLayer
        maskLayer.fillRule = .evenOdd
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        maskLayer.frame = bounds
        updatePath()
    }

    private var cutoutRect: CGRect = .zero
    private var cutoutRadius: CGFloat = 0

    func setCutout(rect: CGRect, cornerRadius: Double) {
        cutoutRect = rect
        cutoutRadius = cornerRadius
        updatePath()
    }

    private func updatePath() {
        let path = UIBezierPath(rect: bounds)
        if !cutoutRect.isEmpty {
            path.append(UIBezierPath(roundedRect: cutoutRect, cornerRadius: cutoutRadius))
        }
        maskLayer.path = path.cgPath
    }

    @objc private func handleTap() { onTap() }
}

// MARK: - OverlayTransitioningDelegate

/// Single transitioning delegate class configured with the presentation
/// kind at init time. Keeps Router.swift free of per-kind delegate
/// classes.
final class OverlayTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    enum Kind {
        case modal(ModalStyle)
        case alert(AlertStyle)
        case drawer(DrawerStyle)
        case popover(PopoverStyle)
        case contextMenu(ContextMenuStyle)
        case coachMark(CoachMarkStyle)
    }

    let kind: Kind

    init(kind: Kind) { self.kind = kind }

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        switch kind {
        case .modal(let style):
            return CenteredPresentationController(
                presented: presented, presenting: presenting,
                barrier: style.barrier, maxWidth: style.maxWidth
            )
        case .alert(let style):
            return CenteredPresentationController(
                presented: presented, presenting: presenting,
                barrier: style.barrier, maxWidth: style.maxWidth
            )
        case .drawer(let style):
            return DrawerPresentationController(presented: presented, presenting: presenting, style: style)
        case .popover(let style):
            return PopoverPresentationController(presented: presented, presenting: presenting, style: style)
        case .contextMenu(let style):
            return ContextMenuPresentationController(presented: presented, presenting: presenting, style: style)
        case .coachMark(let style):
            return CoachMarkPresentationController(presented: presented, presenting: presenting, style: style)
        }
    }

    func animationController(
        forPresented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        animator(isPresenting: true)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        animator(isPresenting: false)
    }

    private func animator(isPresenting: Bool) -> UIViewControllerAnimatedTransitioning? {
        switch kind {
        case .modal(let style):
            return FadeScaleAnimator(duration: style.transitionDuration, initialScale: style.entryScale, isPresenting: isPresenting)
        case .alert(let style):
            return FadeScaleAnimator(duration: style.transitionDuration, initialScale: style.entryScale, isPresenting: isPresenting)
        case .drawer(let style):
            return SlideAnimator(duration: style.transitionDuration, edge: style.edge, isPresenting: isPresenting)
        case .popover(let style):
            return FadeScaleAnimator(duration: style.transitionDuration, initialScale: 0.9, isPresenting: isPresenting)
        case .contextMenu(let style):
            return FadeScaleAnimator(duration: style.transitionDuration, initialScale: 0.9, isPresenting: isPresenting)
        case .coachMark:
            // Coach mark uses barrier crossfade only; content appears immediately.
            return nil
        }
    }
}

#endif
