#if canImport(UIKit)
import UIKit

// MARK: - Gesture

/// A transparent container that attaches gesture recognizers to its
/// platform view. Children are properly parented in the node tree,
/// and gestures coexist with child interactions (buttons, etc.)
/// through UIKit's normal gesture arbitration.
///
/// ```swift
/// Gesture(
///     drag: DragConfig(
///         onStart: { e in ... },
///         onUpdate: { e in ... },
///         onEnd: { e in ... }
///     )
/// ) {
///     MyContent()
/// }
/// ```
public struct Gesture: ContainerView {
    public let children: [any View]
    public let tap: TapConfig?
    public let doubleTap: DoubleTapConfig?
    public let press: PressConfig?
    public let hold: HoldConfig?
    public let drag: DragConfig?
    public let pan: PanConfig?

    public init(
        tap: TapConfig? = nil,
        doubleTap: DoubleTapConfig? = nil,
        press: PressConfig? = nil,
        hold: HoldConfig? = nil,
        drag: DragConfig? = nil,
        pan: PanConfig? = nil,
        @ChildrenBuilder content: () -> [any View]
    ) {
        self.tap = tap; self.doubleTap = doubleTap
        self.press = press; self.hold = hold
        self.drag = drag; self.pan = pan
        self.children = content()
    }

    public init(
        tap: TapConfig? = nil,
        doubleTap: DoubleTapConfig? = nil,
        press: PressConfig? = nil,
        hold: HoldConfig? = nil,
        drag: DragConfig? = nil,
        pan: PanConfig? = nil,
        children: [any View]
    ) {
        self.tap = tap; self.doubleTap = doubleTap
        self.press = press; self.hold = hold
        self.drag = drag; self.pan = pan
        self.children = children
    }

    public func makeRenderer() -> ContainerRenderer {
        GestureRenderer(view: self)
    }
}

// MARK: - Renderer

final class GestureRenderer: ContainerRenderer {
    private weak var gestureView: GestureView?
    private var view: Gesture

    init(view: Gesture) { self.view = view }

    func update(from newView: any View) {
        guard let gesture = newView as? Gesture, let gestureView else { return }
        view = gesture
        gestureView.configure(gesture)
    }

    func mount() -> PlatformView {
        let v = GestureView()
        self.gestureView = v
        v.configure(view)
        return v
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        if index >= container.subviews.count {
            container.addSubview(platformView)
        } else {
            container.insertSubview(platformView, at: index)
        }
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - GestureView

final class GestureView: UIView {
    private var tapRecognizer: UITapGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var panRecognizer: UIPanGestureRecognizer?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var rotationRecognizer: UIRotationGestureRecognizer?

    private var tapConfig: TapConfig?
    private var doubleTapConfig: DoubleTapConfig?
    private var pressConfig: PressConfig?
    private var holdConfig: HoldConfig?
    private var dragConfig: DragConfig?
    private var panConfig: PanConfig?

    // Drag tracking
    private var dragInitialLocal: Vec2 = .zero
    private var dragInitialGlobal: Vec2 = .zero
    private var dragLastLocal: Vec2 = .zero

    // Hold tracking
    private var holdStartTime: Double = 0
    private var holdRecognized = false
    private var holdInitialLocal: Vec2 = .zero
    private var holdInitialGlobal: Vec2 = .zero
    private var holdLastLocal: Vec2 = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize { size }

    override func layoutSubviews() {
        super.layoutSubviews()
        for child in subviews {
            child.frame = bounds
        }
    }

    func configure(_ gesture: Gesture) {
        configureTap(gesture.tap)
        configureDoubleTap(gesture.doubleTap)
        configurePress(gesture.press, hold: gesture.hold)
        configureDrag(gesture.drag)
        configurePan(gesture.pan)
    }

    // MARK: - Tap

    private func configureTap(_ config: TapConfig?) {
        tapConfig = config
        if config != nil {
            if tapRecognizer == nil {
                let r = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                addGestureRecognizer(r)
                tapRecognizer = r
            }
        } else if let r = tapRecognizer {
            removeGestureRecognizer(r)
            tapRecognizer = nil
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let config = tapConfig else { return }
        let pos = gesturePosition(g)
        config.onStart?(TapStart(position: pos))
        config.onEnd?(TapEnd(position: pos))
    }

    // MARK: - Double Tap

    private func configureDoubleTap(_ config: DoubleTapConfig?) {
        doubleTapConfig = config
        if config != nil {
            if doubleTapRecognizer == nil {
                let r = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
                r.numberOfTapsRequired = 2
                addGestureRecognizer(r)
                doubleTapRecognizer = r
                // Make single tap wait for double tap to fail
                tapRecognizer?.require(toFail: r)
            }
        } else if let r = doubleTapRecognizer {
            removeGestureRecognizer(r)
            doubleTapRecognizer = nil
        }
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        guard let config = doubleTapConfig else { return }
        let pos = gesturePosition(g)
        config.onEnd?(DoubleTapEnd(position: pos, firstTapPosition: pos))
    }

    // MARK: - Press / Hold

    private func configurePress(_ press: PressConfig?, hold: HoldConfig?) {
        pressConfig = press
        holdConfig = hold
        let needsRecognizer = press != nil || hold != nil
        if needsRecognizer {
            if longPressRecognizer == nil {
                let r = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                addGestureRecognizer(r)
                longPressRecognizer = r
            }
            let duration = press?.pressDuration ?? hold?.holdThreshold ?? 0.5
            longPressRecognizer?.minimumPressDuration = duration
        } else if let r = longPressRecognizer {
            removeGestureRecognizer(r)
            longPressRecognizer = nil
        }
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        let pos = gesturePosition(g)
        switch g.state {
        case .began:
            holdStartTime = CACurrentMediaTime()
            holdInitialLocal = pos.local
            holdInitialGlobal = pos.global
            holdLastLocal = pos.local
            holdRecognized = true
            pressConfig?.onStart?(LongPressStart(position: pos))
            holdConfig?.onStart?(LongPressStart(position: pos))
        case .changed:
            let elapsed = CACurrentMediaTime() - holdStartTime
            let delta = pos.local - holdLastLocal
            let totalDelta = pos.local - holdInitialLocal
            holdLastLocal = pos.local
            pressConfig?.onUpdate?(LongPressUpdate(position: pos, delta: delta, totalDelta: totalDelta, elapsed: elapsed))
            holdConfig?.onUpdate?(LongPressUpdate(position: pos, delta: delta, totalDelta: totalDelta, elapsed: elapsed))
        case .ended:
            let elapsed = CACurrentMediaTime() - holdStartTime
            let totalDelta = pos.local - holdInitialLocal
            pressConfig?.onEnd?(LongPressEnd(position: pos, totalDelta: totalDelta, elapsed: elapsed))
            holdConfig?.onEnd?(LongPressEnd(position: pos, totalDelta: totalDelta, elapsed: elapsed))
            holdRecognized = false
        case .cancelled, .failed:
            pressConfig?.onCancel?()
            holdConfig?.onCancel?()
            holdRecognized = false
        default: break
        }
    }

    // MARK: - Drag

    private func configureDrag(_ config: DragConfig?) {
        dragConfig = config
        if config != nil {
            if panRecognizer == nil {
                let r = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                addGestureRecognizer(r)
                panRecognizer = r
            }
        } else if panConfig == nil, let r = panRecognizer {
            // Only remove if pan config also doesn't need it
            removeGestureRecognizer(r)
            panRecognizer = nil
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let pos = gesturePosition(g)
        let vel = g.velocity(in: self)

        switch g.state {
        case .began:
            dragInitialLocal = pos.local
            dragInitialGlobal = pos.global
            dragLastLocal = pos.local
            dragConfig?.onStart?(DragStart(
                position: pos,
                initialPosition: GesturePosition(local: dragInitialLocal, global: dragInitialGlobal)
            ))
        case .changed:
            let delta = pos.local - dragLastLocal
            let totalDelta = pos.local - dragInitialLocal
            dragLastLocal = pos.local
            dragConfig?.onUpdate?(DragUpdate(
                position: pos,
                delta: delta,
                totalDelta: totalDelta
            ))
        case .ended:
            let totalDelta = pos.local - dragInitialLocal
            dragConfig?.onEnd?(DragEnd(
                position: pos,
                totalDelta: totalDelta,
                velocity: Vec2(Double(vel.x), Double(vel.y))
            ))
        case .cancelled, .failed:
            dragConfig?.onCancel?()
        default: break
        }
    }

    // MARK: - Pan (multi-pointer)

    private func configurePan(_ config: PanConfig?) {
        panConfig = config
        if config != nil {
            if pinchRecognizer == nil {
                let r = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                addGestureRecognizer(r)
                pinchRecognizer = r
            }
            if rotationRecognizer == nil {
                let r = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
                addGestureRecognizer(r)
                rotationRecognizer = r
            }
            // Allow simultaneous recognition
            pinchRecognizer?.delegate = self
            rotationRecognizer?.delegate = self
        } else {
            if let r = pinchRecognizer { removeGestureRecognizer(r); pinchRecognizer = nil }
            if let r = rotationRecognizer { removeGestureRecognizer(r); rotationRecognizer = nil }
        }
    }

    private var lastScale: CGFloat = 1
    private var lastRotation: CGFloat = 0
    private var totalScale: CGFloat = 1
    private var totalRotation: CGFloat = 0
    private var panStartFocal: Vec2 = .zero
    private var panLastFocal: Vec2 = .zero

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard let config = panConfig else { return }
        let focal = focalPoint(g)
        let pos = GesturePosition(local: focal, global: globalPoint(focal))

        switch g.state {
        case .began:
            lastScale = 1; totalScale = 1
            panStartFocal = focal; panLastFocal = focal
            config.onStart?(PanStart(position: pos, pointerCount: g.numberOfTouches))
        case .changed:
            let scaleDelta = g.scale / lastScale
            lastScale = g.scale
            totalScale *= scaleDelta
            let focalDelta = focal - panLastFocal
            let totalFocalDelta = focal - panStartFocal
            panLastFocal = focal
            config.onUpdate?(PanUpdate(
                position: pos,
                focalDelta: focalDelta, totalFocalDelta: totalFocalDelta,
                scale: Double(totalScale), scaleDelta: Double(scaleDelta),
                rotation: Double(totalRotation), rotationDelta: 0,
                pointerCount: g.numberOfTouches
            ))
        case .ended:
            let totalFocalDelta = focal - panStartFocal
            config.onEnd?(PanEnd(
                position: pos,
                totalFocalDelta: totalFocalDelta,
                scale: Double(totalScale), rotation: Double(totalRotation),
                velocity: .zero, pointerCount: g.numberOfTouches
            ))
        case .cancelled, .failed:
            config.onCancel?()
        default: break
        }
    }

    @objc private func handleRotation(_ g: UIRotationGestureRecognizer) {
        guard panConfig != nil else { return }
        switch g.state {
        case .began:
            lastRotation = 0; totalRotation = 0
        case .changed:
            let delta = g.rotation - lastRotation
            lastRotation = g.rotation
            totalRotation += delta
        default: break
        }
    }

    // MARK: - Helpers

    private func gesturePosition(_ g: UIGestureRecognizer) -> GesturePosition {
        let local = g.location(in: self)
        let global = g.location(in: nil)
        return GesturePosition(
            local: Vec2(Double(local.x), Double(local.y)),
            global: Vec2(Double(global.x), Double(global.y))
        )
    }

    private func focalPoint(_ g: UIGestureRecognizer) -> Vec2 {
        let p = g.location(in: self)
        return Vec2(Double(p.x), Double(p.y))
    }

    private func globalPoint(_ local: Vec2) -> Vec2 {
        let p = convert(CGPoint(x: local.x, y: local.y), to: nil)
        return Vec2(Double(p.x), Double(p.y))
    }
}

// MARK: - UIGestureRecognizerDelegate

extension GestureView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Allow pinch + rotation to work simultaneously
        let isPinchOrRotation = gestureRecognizer is UIPinchGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer
        let otherIsPinchOrRotation = other is UIPinchGestureRecognizer || other is UIRotationGestureRecognizer
        return isPinchOrRotation && otherIsPinchOrRotation
    }
}

#endif
