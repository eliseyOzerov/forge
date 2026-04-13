import Foundation

// MARK: - Curve

/// Maps a linear time value (0→1) to an eased output value.
/// The fundamental animation primitive — everything else builds on this.
public typealias Curve = Mapper<Double, Double>

public extension Curve {

    // MARK: Standard curves

    nonisolated(unsafe) static let linear = Curve { $0 }
    nonisolated(unsafe) static let easeIn = Curve { $0 * $0 }
    nonisolated(unsafe) static let easeOut = Curve { 1 - (1 - $0) * (1 - $0) }
    nonisolated(unsafe) static let easeInOut = Curve { t in
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    nonisolated(unsafe) static let overshoot = Curve { t in
        let c = 1.70158
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }
    nonisolated(unsafe) static let bounce = Curve { t in
        if t < 1 / 2.75 { return 7.5625 * t * t }
        if t < 2 / 2.75 { let t = t - 1.5 / 2.75; return 7.5625 * t * t + 0.75 }
        if t < 2.5 / 2.75 { let t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375 }
        let t = t - 2.625 / 2.75; return 7.5625 * t * t + 0.984375
    }

    // MARK: Cubic bezier

    /// CSS-style cubic bezier: cubic-bezier(x1, y1, x2, y2).
    /// Control points define the curve shape. Start is (0,0), end is (1,1).
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Curve {
        Curve { t in
            // Newton-Raphson to find the t parameter for the given x
            var guess = t
            for _ in 0..<8 {
                let x = cubicBezierSample(guess, a: x1, b: x2) - t
                let dx = cubicBezierSlope(guess, a: x1, b: x2)
                guard abs(dx) > 1e-6 else { break }
                guess -= x / dx
            }
            return cubicBezierSample(guess, a: y1, b: y2)
        }
    }

    // MARK: Keyframes

    /// Multi-stop curve with values at fractional positions.
    /// Interpolates between stops using the provided curve (applied per segment).
    ///
    /// ```swift
    /// // Overshoot and settle:
    /// Curve.keyframes([(0, 0), (0.6, 1.1), (0.8, 0.95), (1.0, 1.0)], curve: .easeInOut)
    /// ```
    static func keyframes(_ stops: [(position: Double, value: Double)], curve: Curve = .linear) -> Curve {
        guard stops.count >= 2 else { return .linear }
        let sorted = stops.sorted { $0.position < $1.position }
        return Curve { t in
            if t <= sorted.first!.position { return sorted.first!.value }
            if t >= sorted.last!.position { return sorted.last!.value }
            for i in 0..<sorted.count - 1 {
                let a = sorted[i], b = sorted[i + 1]
                if t >= a.position && t <= b.position {
                    let segmentT = (t - a.position) / (b.position - a.position)
                    let eased = curve(segmentT)
                    return a.value + (b.value - a.value) * eased
                }
            }
            return sorted.last!.value
        }
    }

    /// Keyframes with per-segment curves. `curves` array length should be
    /// `stops.count - 1` (one curve per gap). Falls back to linear for
    /// missing entries.
    static func keyframes(_ stops: [(position: Double, value: Double)], curves: [Curve]) -> Curve {
        guard stops.count >= 2 else { return .linear }
        let sorted = stops.sorted { $0.position < $1.position }
        return Curve { t in
            if t <= sorted.first!.position { return sorted.first!.value }
            if t >= sorted.last!.position { return sorted.last!.value }
            for i in 0..<sorted.count - 1 {
                let a = sorted[i], b = sorted[i + 1]
                if t >= a.position && t <= b.position {
                    let segmentT = (t - a.position) / (b.position - a.position)
                    let segCurve = i < curves.count ? curves[i] : .linear
                    let eased = segCurve(segmentT)
                    return a.value + (b.value - a.value) * eased
                }
            }
            return sorted.last!.value
        }
    }
}

// MARK: - Bezier math

private func cubicBezierSample(_ t: Double, a: Double, b: Double) -> Double {
    // Bernstein polynomial for cubic bezier with endpoints at 0 and 1
    let t2 = t * t, t3 = t2 * t
    return 3 * a * t * (1 - t) * (1 - t) + 3 * b * t2 * (1 - t) + t3
}

private func cubicBezierSlope(_ t: Double, a: Double, b: Double) -> Double {
    let t2 = t * t
    return 3 * a * (1 - t) * (1 - t) - 6 * a * t * (1 - t) + 6 * b * t * (1 - t) - 3 * b * t2 + 3 * t2
}

// MARK: - Animation

/// Duration + delay + curve for a single animated transition.
public struct Animation {
    public var duration: Double
    public var delay: Double
    public var curve: Curve

    public init(duration: Double = 0.2, delay: Double = 0, curve: Curve = .easeInOut) {
        self.duration = duration
        self.delay = delay
        self.curve = curve
    }

    nonisolated(unsafe) public static let `default` = Animation()
    nonisolated(unsafe) public static let fast = Animation(duration: 0.1)
    nonisolated(unsafe) public static let slow = Animation(duration: 0.4)
    nonisolated(unsafe) public static let none = Animation(duration: 0)

    /// Apply the curve to a linear t value (clamped to 0...1).
    public func apply(_ t: Double) -> Double {
        curve(min(max(t, 0), 1))
    }
}

// MARK: - Track

/// One animated value within a Motion. Defines start/end values
/// and optional per-track timing overrides.
public struct Track {
    public var from: Double
    public var to: Double
    public var curve: Curve?     // nil = use Motion's curve
    public var delay: Double     // relative to Motion start

    public init(from: Double = 0, to: Double = 1, curve: Curve? = nil, delay: Double = 0) {
        self.from = from; self.to = to
        self.curve = curve; self.delay = delay
    }
}

// MARK: - Motion

/// Multi-track animation driven by a single time source.
/// Each track interpolates its own from→to value with its own
/// curve and delay, all sharing one duration.
///
/// ```swift
/// let enter = Motion(duration: 0.35, tracks: [
///     Track(from: 0, to: 1, curve: .easeOut),              // opacity
///     Track(from: 100, to: 0, curve: .easeOut, delay: 0.05), // offsetY
///     Track(from: 0.9, to: 1, curve: .overshoot, delay: 0.02), // scale
/// ])
/// enter.target([1, 0, 1])  // animate to targets
/// ```
@MainActor
public final class Motion {
    public let tracks: [Track]
    public var duration: Double
    public var curve: Curve

    /// Current interpolated values — read this each frame.
    public private(set) var values: [Double]

    /// Where we're animating from (captured at target time).
    private var fromValues: [Double]
    /// Where we're animating to.
    private var toValues: [Double]

    private var startTime: CFTimeInterval = 0
    private var running = false

    /// Callback fired every frame while animating.
    public var onTick: (() -> Void)?
    /// Callback fired when animation completes.
    public var onComplete: (() -> Void)?

    public init(duration: Double = 0.3, curve: Curve = .easeInOut, tracks: [Track]) {
        self.duration = duration
        self.curve = curve
        self.tracks = tracks
        self.values = tracks.map { $0.from }
        self.fromValues = tracks.map { $0.from }
        self.toValues = tracks.map { $0.from }
    }

    /// Set new targets. Animation starts from current values.
    /// Optionally override duration and curves for this transition.
    public func target(_ targets: [Double], duration: Double? = nil, curves overrideCurve: Curve? = nil) {
        guard targets.count == tracks.count else { return }
        fromValues = values
        toValues = targets
        if let d = duration { self.duration = d }
        startTime = CACurrentMediaTime()
        running = true
    }

    /// Convenience: reverse all tracks to their `from` values.
    public func reverse(duration: Double? = nil, curves overrideCurve: Curve? = nil) {
        target(tracks.map { $0.from }, duration: duration, curves: overrideCurve)
    }

    /// Convenience: forward all tracks to their `to` values.
    public func forward(duration: Double? = nil) {
        target(tracks.map { $0.to }, duration: duration)
    }

    public var isRunning: Bool { running }

    /// Advance the animation. Called by the driver each frame.
    public func tick() {
        guard running, startTime > 0 else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let totalDuration = effectiveDuration

        if elapsed >= totalDuration {
            values = toValues
            running = false
            startTime = 0
            onComplete?()
            onTick?()
            return
        }

        for i in 0..<tracks.count {
            let track = tracks[i]
            let trackDelay = track.delay
            let trackElapsed = elapsed - trackDelay

            if trackElapsed <= 0 {
                values[i] = fromValues[i]
            } else {
                let trackDuration = duration // all tracks share the base duration
                let linearT = min(trackElapsed / trackDuration, 1)
                let trackCurve = track.curve ?? curve
                let eased = trackCurve(linearT)
                values[i] = fromValues[i] + (toValues[i] - fromValues[i]) * eased
            }
        }

        onTick?()
    }

    /// Total duration including maximum track delay.
    private var effectiveDuration: Double {
        let maxDelay = tracks.reduce(0.0) { max($0, $1.delay) }
        return duration + maxDelay
    }
}

// MARK: - MotionDriver

/// Platform-agnostic protocol for driving Motion updates.
@MainActor
public protocol MotionDriver: AnyObject {
    func start()
    func stop()
    var motion: Motion? { get set }
}

// MARK: - CADisplayLink Driver (iOS)

#if canImport(UIKit)
import UIKit

@MainActor
public final class DisplayLinkDriver: MotionDriver {
    public weak var motion: Motion?
    private var displayLink: CADisplayLink?
    private var view: UIView?

    public init() {}

    /// Attach to a view so display link triggers redraws.
    public func attach(to view: UIView) {
        self.view = view
    }

    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let motion else { stop(); return }
        motion.tick()
        view?.setNeedsDisplay()
        if !motion.isRunning { stop() }
    }
}

#endif
