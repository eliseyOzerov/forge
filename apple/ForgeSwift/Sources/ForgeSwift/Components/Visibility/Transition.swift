//
//  Transition.swift
//  ForgeSwift
//
//  Enter/exit animation wrapper. `show` drives a 0→1 animation; each
//  configured TransitionEffect contributes to a single ResolvedTransform
//  (alpha + translation + scale + rotation) applied to the child's
//  platform view each tick. Effects compose: Fade + Scale + Slide all
//  work on one child without fighting over UIView.transform.
//
//  ```swift
//  Transition(
//      show: $isVisible,
//      effects: [Fade(), Scale(0.9), Slide(y: 20)],
//      duration: 0.25
//  ) {
//      Box(.fill, .color(.red))
//  }
//  ```
//
//  Mirrors Wave's Transition widget. animateSize (layout-space clip)
//  is deferred — v1 only does paint-level transforms.
//

#if canImport(UIKit)
import UIKit

// MARK: - TransitionStatus

public enum TransitionStatus: Sendable {
    case entering
    case entered
    case exiting
    case exited
}

// MARK: - TransitionState

/// Accumulator for an effect stack's contributions in a single frame.
/// Effects mutate this; the host applies it to a UIView once per tick.
public struct TransitionState {
    public var alpha: Double = 1
    public var translationX: Double = 0
    public var translationY: Double = 0
    public var scaleX: Double = 1
    public var scaleY: Double = 1
    /// Z-axis rotation in radians.
    public var rotation: Double = 0
}

// MARK: - TransitionEffect

public protocol TransitionEffect {
    /// Timing curve applied to t before this effect reads it.
    var curve: Curve { get }

    /// Contribute to the shared transform state at parent progress t
    /// (0…1, linear). Implementations should eval `curve(t)` before
    /// interpolating their own from/to values.
    func contribute(to state: inout TransitionState, t: Double)
}

public extension TransitionEffect {
    var curve: Curve { .linear }
}

// MARK: - Built-in effects

/// Fades alpha from `from` at t=0 to `to` at t=1. Default: fade in.
public struct Fade: TransitionEffect {
    public var from: Double
    public var to: Double
    public var curve: Curve

    public init(from: Double = 0, to: Double = 1, curve: Curve = .linear) {
        self.from = from
        self.to = to
        self.curve = curve
    }

    public func contribute(to state: inout TransitionState, t: Double) {
        let p = curve(t)
        state.alpha = from + (to - from) * p
    }
}

/// Scales the child. `Scale(0.9)` → scale in from 0.9 to 1 on enter.
/// Use `.xy(_, _)` for non-uniform scaling.
public struct Scale: TransitionEffect {
    public var fromX: Double
    public var fromY: Double
    public var toX: Double
    public var toY: Double
    public var curve: Curve

    public init(_ from: Double, to: Double = 1, curve: Curve = .linear) {
        self.fromX = from
        self.fromY = from
        self.toX = to
        self.toY = to
        self.curve = curve
    }

    public static func xy(
        fromX: Double, fromY: Double,
        toX: Double = 1, toY: Double = 1,
        curve: Curve = .linear
    ) -> Scale {
        var s = Scale(fromX, to: toX, curve: curve)
        s.fromX = fromX; s.fromY = fromY; s.toX = toX; s.toY = toY
        return s
    }

    public func contribute(to state: inout TransitionState, t: Double) {
        let p = curve(t)
        state.scaleX *= fromX + (toX - fromX) * p
        state.scaleY *= fromY + (toY - fromY) * p
    }
}

/// Translates the child by an offset in points. `Slide(y: 20)` slides
/// up 20pt on exit (from y=20 to y=0 on enter).
public struct Slide: TransitionEffect {
    public var fromX: Double
    public var fromY: Double
    public var toX: Double
    public var toY: Double
    public var curve: Curve

    public init(x: Double = 0, y: Double = 0, toX: Double = 0, toY: Double = 0, curve: Curve = .linear) {
        self.fromX = x
        self.fromY = y
        self.toX = toX
        self.toY = toY
        self.curve = curve
    }

    public func contribute(to state: inout TransitionState, t: Double) {
        let p = curve(t)
        state.translationX += fromX + (toX - fromX) * p
        state.translationY += fromY + (toY - fromY) * p
    }
}

/// Rotates around Z in radians.
public struct Rotate: TransitionEffect {
    public var from: Double
    public var to: Double
    public var curve: Curve

    public init(_ angle: Double, to: Double = 0, curve: Curve = .linear) {
        self.from = angle
        self.to = to
        self.curve = curve
    }

    public func contribute(to state: inout TransitionState, t: Double) {
        let p = curve(t)
        state.rotation += from + (to - from) * p
    }
}

// MARK: - Transition view

public struct Transition: LeafView {
    public let show: Binding<Bool>
    public let effects: [any TransitionEffect]
    public let duration: Double
    public let curve: Curve
    public let onStatus: ((TransitionStatus) -> Void)?
    public let child: any View

    public init(
        show: Binding<Bool>,
        effects: [any TransitionEffect] = [],
        duration: Double = 0.3,
        curve: Curve = .easeOut,
        onStatus: ((TransitionStatus) -> Void)? = nil,
        @ChildBuilder child: () -> any View
    ) {
        self.show = show
        self.effects = effects
        self.duration = duration
        self.curve = curve
        self.onStatus = onStatus
        self.child = child()
    }

    public func makeRenderer() -> Renderer {
        TransitionRenderer(
            show: show.value,
            effects: effects,
            duration: duration,
            curve: curve,
            onStatus: onStatus,
            child: child
        )
    }
}

final class TransitionRenderer: Renderer {
    var show: Bool
    var effects: [any TransitionEffect]
    var duration: Double
    var curve: Curve
    var onStatus: ((TransitionStatus) -> Void)?
    var child: any View

    init(
        show: Bool,
        effects: [any TransitionEffect],
        duration: Double,
        curve: Curve,
        onStatus: ((TransitionStatus) -> Void)?,
        child: any View
    ) {
        self.show = show
        self.effects = effects
        self.duration = duration
        self.curve = curve
        self.onStatus = onStatus
        self.child = child
    }

    func mount() -> PlatformView {
        let v = TransitionView()
        v.configure(
            child: child,
            effects: effects,
            duration: duration,
            curve: curve,
            show: show,
            onStatus: onStatus
        )
        return v
    }

    func update(_ platformView: PlatformView) {
        guard let v = platformView as? TransitionView else { return }
        v.configure(
            child: child,
            effects: effects,
            duration: duration,
            curve: curve,
            show: show,
            onStatus: onStatus
        )
    }
}

final class TransitionView: UIView {
    private var childNode: Node?
    private var effects: [any TransitionEffect] = []
    private var duration: Double = 0.3
    private var motionCurve: Curve = .easeOut
    private var onStatus: ((TransitionStatus) -> Void)?
    private var showValue: Bool = false
    private var initialized = false

    private var motion: Motion?
    private let driver = DisplayLinkDriver()

    override init(frame: CGRect) {
        super.init(frame: frame)
        driver.attach(to: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        childNode?.platformView?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        childNode?.platformView?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        childNode?.platformView?.frame = bounds
        applyT()
    }

    func configure(
        child: any View,
        effects: [any TransitionEffect],
        duration: Double,
        curve: Curve,
        show: Bool,
        onStatus: ((TransitionStatus) -> Void)?
    ) {
        let firstTime = !initialized
        initialized = true

        self.effects = effects
        self.duration = duration
        self.motionCurve = curve
        self.onStatus = onStatus

        // Mount or update child.
        if let existing = childNode, existing.canUpdate(to: child) {
            existing.update(from: child)
        } else {
            childNode?.platformView?.removeFromSuperview()
            let node = Node.inflate(child)
            childNode = node
            if let pv = node.platformView {
                addSubview(pv)
                pv.frame = bounds
            }
        }

        if firstTime {
            let m = Motion(
                duration: duration,
                curve: curve,
                tracks: [Track(from: 0, to: 1)]
            )
            m.onTick = { [weak self] in
                self?.applyT()
                self?.setNeedsLayout()
            }
            m.onComplete = { [weak self] in
                guard let self else { return }
                self.onStatus?(self.showValue ? .entered : .exited)
            }
            motion = m
            driver.motion = m
            applyT()
        } else {
            motion?.duration = duration
            motion?.curve = curve
        }

        guard let motion else { return }
        if firstTime {
            // Initial mount: if show is true, play enter. Otherwise sit at 0
            // (Motion's initial values mirror track.from = 0, so nothing to do).
            if show {
                showValue = true
                onStatus?(.entering)
                motion.target([1])
                driver.start()
            } else {
                showValue = false
                applyT()
            }
        } else if showValue != show {
            showValue = show
            if show {
                onStatus?(.entering)
                motion.target([1])
            } else {
                onStatus?(.exiting)
                motion.target([0])
            }
            driver.start()
        }
    }

    private func applyT() {
        guard let motion, let pv = childNode?.platformView else { return }
        let t = motion.values[0]
        var state = TransitionState()
        for effect in effects {
            effect.contribute(to: &state, t: t)
        }
        pv.alpha = CGFloat(state.alpha)
        pv.transform = CGAffineTransform.identity
            .translatedBy(x: CGFloat(state.translationX), y: CGFloat(state.translationY))
            .scaledBy(x: CGFloat(state.scaleX), y: CGFloat(state.scaleY))
            .rotated(by: CGFloat(state.rotation))
    }
}

#endif
