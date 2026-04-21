import Foundation
import QuartzCore

// MARK: - Animation

/// Duration + delay + curve for a single animated transition.
public struct Animation: Equatable {
    public var duration: Double
    public var delay: Double
    public var curve: Curve

    public static func ==(lhs: Animation, rhs: Animation) -> Bool {
        lhs.duration == rhs.duration && lhs.delay == rhs.delay && lhs.curve.id == rhs.curve.id
    }

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

// MARK: - Curve

/// Maps a linear time value (0→1) to an eased output value.
/// The fundamental animation primitive — everything else builds on this.
public typealias Curve = Mapper<Double, Double>

public extension Curve {

    // MARK: Standard curves

    nonisolated(unsafe) static let linear = Curve("linear") { $0 }
    nonisolated(unsafe) static let easeIn = Curve("easeIn") { $0 * $0 }
    nonisolated(unsafe) static let easeOut = Curve("easeOut") { 1 - (1 - $0) * (1 - $0) }
    nonisolated(unsafe) static let easeInOut = Curve("easeInOut") { t in
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    nonisolated(unsafe) static let overshoot = Curve("overshoot") { t in
        let c = 1.70158
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }
    nonisolated(unsafe) static let bounce = Curve("bounce") { t in
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

/// A tick source that runs for a given duration and exposes linear progress (0→1).
/// Subclass of Observable<Double> — observe it to get progress values directly.
///
/// ```swift
/// let driver = MotionDriver(duration: Duration(0.3))
/// driver.observe { progress in /* 0...1 */ }
/// driver.forward()   // value: 0 → 1
/// driver.reverse()   // value: 1 → 0
/// driver.seek(to: 0.5) // jump to midpoint
/// ```
@MainActor
public final class MotionDriver: Observable<Double> {

    /// Duration of a full forward or reverse run.
    public var duration: Duration

    public private(set) var state: State = .idle

    /// Driver state: idle, running, paused, or completed.
    public enum State: Equatable, Sendable {
        case idle
        case forward
        case reverse
        case paused(direction: Direction)
    }

    /// Driver playback direction: forward or reverse.
    public enum Direction: Equatable, Sendable {
        case forward, reverse
    }

    private var startTime: CFTimeInterval = 0
    private var startProgress: Double = 0
    private var continuation: CheckedContinuation<Bool, Never>?

    public init(duration: Duration = Duration(0.3)) {
        self.duration = duration
        super.init(0)
    }

    // MARK: - Controls

    /// Animate progress from current value to 1.
    @discardableResult
    public func forward() async -> Bool {
        await run(direction: .forward)
    }

    /// Animate progress from current value to 0.
    @discardableResult
    public func reverse() async -> Bool {
        await run(direction: .reverse)
    }

    /// Pause a running animation. Resume with `resume()`.
    public func pause() {
        switch state {
        case .forward:
            state = .paused(direction: .forward)
            stopTicker()
        case .reverse:
            state = .paused(direction: .reverse)
            stopTicker()
        default: break
        }
    }

    /// Resume a paused animation.
    public func resume() {
        guard case .paused(let direction) = state else { return }
        startProgress = value
        startTime = CACurrentMediaTime()
        state = direction == .forward ? .forward : .reverse
        startTicker()
    }

    /// Stop and reset to 0.
    public func reset() {
        cancel()
        value = 0
    }

    /// Jump to a specific progress value. Cancels any running animation.
    public func seek(to target: Double) {
        cancel()
        value = min(max(target, 0), 1)
    }

    public var isRunning: Bool {
        state == .forward || state == .reverse
    }

    // MARK: - Internal

    private func run(direction: Direction) async -> Bool {
        cancel()

        let target: Double = direction == .forward ? 1 : 0
        guard value != target else { return true }

        let distance = abs(target - value)
        let effectiveSeconds = duration.seconds * distance
        guard effectiveSeconds > 0 else {
            value = target
            return true
        }

        startProgress = value
        startTime = CACurrentMediaTime()
        state = direction == .forward ? .forward : .reverse

        startTicker()

        return await withCheckedContinuation { cont in
            self.continuation = cont
        }
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let target: Double
        let direction: Direction

        switch state {
        case .forward: target = 1; direction = .forward
        case .reverse: target = 0; direction = .reverse
        default: return
        }

        let distance = abs(target - startProgress)
        let effectiveSeconds = duration.seconds * distance
        let linearT = min(elapsed / effectiveSeconds, 1)

        if direction == .forward {
            value = min(startProgress + distance * linearT, 1)
        } else {
            value = max(startProgress - distance * linearT, 0)
        }

        if linearT >= 1 {
            value = target
            finish(completed: true)
        }
    }

    private func cancel() {
        guard state != .idle else { return }
        stopTicker()
        state = .idle
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: false)
        }
    }

    private func finish(completed: Bool) {
        stopTicker()
        state = .idle
        let cont = continuation
        continuation = nil
        cont?.resume(returning: completed)
    }

    // MARK: - Platform ticker

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?

    private func startTicker() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTicker() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkFired() {
        tick()
    }
    #else
    private func startTicker() {}
    private func stopTicker() {}
    #endif
}

// MARK: - Lerpable

/// A type that can be linearly interpolated between two values.
/// `t` ranges from 0 (self) to 1 (other).
public protocol Lerpable {
    func lerp(to other: Self, t: Double) -> Self
}

extension Double: Lerpable {
    public func lerp(to other: Double, t: Double) -> Double {
        self + (other - self) * t
    }
}

extension Float: Lerpable {
    public func lerp(to other: Float, t: Double) -> Float {
        self + (other - self) * Float(t)
    }
}

extension Int: Lerpable {
    public func lerp(to other: Int, t: Double) -> Int {
        Int(Double(self) + Double(other - self) * t)
    }
}

/// Lerp two optional Lerpable values. If both present, lerp. Otherwise snap.
public func lerpOptional<T: Lerpable>(_ a: T?, _ b: T?, t: Double) -> T? {
    guard let a, let b else { return t < 0.5 ? a : b }
    return a.lerp(to: b, t: t)
}

// MARK: - Mergeable

/// A type whose instances can be merged, with `self`'s non-nil fields
/// winning and `other`'s filling the gaps.
/// `explicit.merge(theme).merge(defaults)` — left to right, highest priority first.
public protocol Mergeable {
    func merge(_ other: Self) -> Self
}

public extension Mergeable {
    func merge(_ other: Self?) -> Self {
        guard let other else { return self }
        return merge(other)
    }
}
