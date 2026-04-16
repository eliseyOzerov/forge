import Foundation

// MARK: - Plane

/// A gesture primitive that turns pan gestures into offset values.
/// Everything that involves dragging builds on this: sliders, knobs,
/// segmented controls, drag-to-reorder, chart scrubbers.
///
/// Two-stage transform pipeline:
/// - `active`: constrains position every frame during drag
/// - `target`: snaps to final position on release, with animation
///
/// ```swift
/// Plane(
///     offset: $thumbPosition,
///     active: .horizontal,            // lock to x-axis
///     target: .snap(to: detents),     // snap to nearest detent
///     animation: Animation(duration: 0.25, curve: .easeOut)
/// ) {
///     Circle(size: 24, color: .blue)
/// }
/// ```
public struct Plane: ModelView {
    public let offset: Binding<Vec2>
    public let active: DragTransform?
    public let target: DragTransform?
    public let animation: Animation
    public let anchor: Bool
    public let relative: Bool
    public let states: State
    public let onStart: ValueHandler<Vec2>?
    public let onChanged: ValueHandler<Vec2>?
    public let onEnd: ValueHandler<Vec2>?
    public let body: any View

    public init(
        offset: Binding<Vec2>,
        active: DragTransform? = nil,
        target: DragTransform? = nil,
        animation: Animation = Animation(duration: 0.3, curve: .easeOut),
        anchor: Bool = true,
        relative: Bool = false,
        states: State = .idle,
        onStart: ValueHandler<Vec2>? = nil,
        onChanged: ValueHandler<Vec2>? = nil,
        onEnd: ValueHandler<Vec2>? = nil,
        @ChildBuilder body: () -> any View
    ) {
        self.offset = offset; self.active = active; self.target = target
        self.animation = animation; self.anchor = anchor; self.relative = relative
        self.states = states
        self.onStart = onStart; self.onChanged = onChanged; self.onEnd = onEnd
        self.body = body()
    }

    public func model(context: BuildContext) -> PlaneModel { PlaneModel(context: context) }
    public func builder(model: PlaneModel) -> PlaneBuilder { PlaneBuilder(model: model) }
}

// MARK: - Model

public final class PlaneModel: ViewModel<Plane> {
    var isPressed = false
    var anchorOffset: Vec2 = .zero
    var containerSize: Size = .zero
    var motion: Motion = Motion(duration: 0.3, tracks: [Track(), Track()])

    public override func didInit(view: Plane) {
        super.didInit(view: view)
        motion = Motion(
            duration: view.animation.duration,
            curve: view.animation.curve,
            tracks: [Track(from: view.offset.value.x, to: view.offset.value.x),
                     Track(from: view.offset.value.y, to: view.offset.value.y)]
        )
    }

    var isDisabled: Bool { view.states.contains(.disabled) }

    var currentState: State {
        var state = view.states
        if isPressed { state.insert(.pressed) }
        return state
    }

    var currentOffset: Vec2 {
        if motion.isRunning {
            return Vec2(motion.values[0], motion.values[1])
        }
        return view.offset.value
    }

    // MARK: Gesture

    func handleDragStart(at position: Vec2) {
        guard !isDisabled else { return }
        rebuild {
            isPressed = true
            if view.anchor {
                anchorOffset = position - toAbsolute(view.offset.value)
            } else {
                anchorOffset = .zero
            }
        }
        view.onStart?(view.offset.value)
    }

    func handleDragUpdate(at position: Vec2) {
        guard isPressed else { return }

        var raw = position - anchorOffset
        if view.relative { raw = toRelative(raw) }
        if let active = view.active { raw = active(raw) }

        rebuild { view.offset.value = raw }
        view.onChanged?(raw)
    }

    func handleDragEnd() {
        guard isPressed else { return }

        var final = view.offset.value
        if let target = view.target {
            final = target(final)
        }

        rebuild {
            isPressed = false
            if final != view.offset.value {
                // Animate to snap target
                motion.duration = view.animation.duration
                motion.curve = view.animation.curve
                motion = Motion(
                    duration: view.animation.duration,
                    curve: view.animation.curve,
                    tracks: [Track(from: view.offset.value.x, to: final.x),
                             Track(from: view.offset.value.y, to: final.y)]
                )
                motion.onTick = { [weak self] in
                    guard let self else { return }
                    rebuild { view.offset.value = Vec2(motion.values[0], motion.values[1]) }
                }
                motion.onComplete = { [weak self] in
                    guard let self else { return }
                    view.offset.value = final
                }
                motion.forward()
            }
        }
        view.onEnd?(final)
    }

    func handleDragCancel() {
        rebuild { isPressed = false }
    }

    // MARK: Coordinate conversion

    func toRelative(_ absolute: Vec2) -> Vec2 {
        guard containerSize.width > 0, containerSize.height > 0 else { return absolute }
        return Vec2(absolute.x / containerSize.width, absolute.y / containerSize.height)
    }

    func toAbsolute(_ relative: Vec2) -> Vec2 {
        if !view.relative { return relative }
        return Vec2(relative.x * containerSize.width, relative.y * containerSize.height)
    }
}

// MARK: - Builder

public final class PlaneBuilder: ViewBuilder<PlaneModel> {
    public override func build(context: BuildContext) -> any View {
        PlaneLeaf(model: model)
    }
}

// MARK: - Leaf

struct PlaneLeaf: LeafView {
    let model: PlaneModel
    func makeRenderer() -> Renderer { PlaneRenderer(model: model) }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class PlaneRenderer: Renderer {
    let model: PlaneModel

    init(model: PlaneModel) { self.model = model }

    func mount() -> PlatformView {
        let view = PlaneView()
        view.model = model
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? PlaneView else { return }
        view.model = model
        if model.motion.isRunning { view.startAnimation() }
    }
}

final class PlaneView: UIView {
    weak var model: PlaneModel?
    private var panGesture: UIPanGestureRecognizer!
    private let driver = DisplayLinkDriver()

    override init(frame: CGRect) {
        super.init(frame: frame)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) { fatalError() }

    func startAnimation() {
        driver.motion = model?.motion
        driver.attach(to: self)
        driver.start()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        model?.containerSize = Size(Double(bounds.width), Double(bounds.height))

        // Position child at current offset
        if let child = subviews.first, let model {
            let offset = model.currentOffset
            let absolute = model.toAbsolute(offset)
            child.frame.origin = CGPoint(x: absolute.x, y: absolute.y)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let pos = Vec2(Double(location.x), Double(location.y))

        switch gesture.state {
        case .began:
            model?.handleDragStart(at: pos)
        case .changed:
            model?.handleDragUpdate(at: pos)
            layoutSubviews()
        case .ended:
            model?.handleDragEnd()
        case .cancelled, .failed:
            model?.handleDragCancel()
        default: break
        }
    }

    override var isAccessibilityElement: Bool { get { true } set {} }
    override var accessibilityTraits: UIAccessibilityTraits { get { .adjustable } set {} }

    override func removeFromSuperview() {
        driver.stop()
        super.removeFromSuperview()
    }
}

#endif

// MARK: - DragTransform

/// Transforms a 2D offset during or after a drag gesture.
/// Used as the `active` (during drag) and `target` (snap on release)
/// parameters of Draggable.
public typealias DragTransform = Mapper<Vec2, Vec2>

// MARK: - Axis

public extension DragTransform {
    /// Lock to horizontal axis (zero out y).
    nonisolated(unsafe) static let horizontal = DragTransform { Vec2($0.x, 0) }

    /// Lock to vertical axis (zero out x).
    nonisolated(unsafe) static let vertical = DragTransform { Vec2(0, $0.y) }
}

// MARK: - Clamp

public extension DragTransform {
    /// Clamp position into a rectangle.
    static func clamp(to rect: Rect) -> DragTransform {
        DragTransform { pos in
            Vec2(
                min(max(pos.x, rect.x), rect.x + rect.width),
                min(max(pos.y, rect.y), rect.y + rect.height)
            )
        }
    }

    /// Clamp position into a circular region.
    static func disc(center: Vec2, radius: Double) -> DragTransform {
        DragTransform { pos in
            let d = pos - center
            if d.lengthSquared <= radius * radius { return pos }
            return center + d.normalized * radius
        }
    }
}

// MARK: - Projection

public extension DragTransform {
    /// Project position onto a line segment from `start` to `end`.
    static func line(from start: Vec2, to end: Vec2) -> DragTransform {
        DragTransform { pos in
            let d = end - start
            let lenSq = d.lengthSquared
            guard lenSq > 0 else { return start }
            let t = min(max((pos - start).dot(d) / lenSq, 0), 1)
            return start + d * t
        }
    }
}

// MARK: - Snap

public extension DragTransform {
    /// Snap to the nearest point in a list. O(n) per call.
    static func snap(to points: [Vec2]) -> DragTransform {
        DragTransform { pos in
            guard !points.isEmpty else { return pos }
            var best = points[0]
            var bestDist = pos.distanceSquared(to: best)
            for p in points.dropFirst() {
                let d = pos.distanceSquared(to: p)
                if d < bestDist { best = p; bestDist = d }
            }
            return best
        }
    }

    /// Snap to the nearest sampled point along a path.
    static func path(_ path: Path, samples: Int = 100) -> DragTransform {
        let points = path.sample(count: samples).map(\.point)
        return snap(to: points)
    }

    /// Snap to a grid with the given cell size.
    static func grid(cellSize: Vec2) -> DragTransform {
        DragTransform { pos in
            Vec2(
                (pos.x / cellSize.x).rounded() * cellSize.x,
                (pos.y / cellSize.y).rounded() * cellSize.y
            )
        }
    }
}

// MARK: - Magnet

public extension DragTransform {
    /// Pull position toward a target transform with configurable strength.
    /// `strength` 0...1 controls how hard the pull is (1 = snap immediately).
    /// `radius` limits the pull range — beyond it, position is unchanged.
    static func magnet(_ target: DragTransform, strength: Double = 0.5, radius: Double? = nil) -> DragTransform {
        DragTransform { pos in
            let snapped = target(pos)
            let dist = pos.distance(to: snapped)
            if let r = radius, dist > r { return pos }
            return pos.lerp(to: snapped, t: strength)
        }
    }
}

// MARK: - Composition

public extension DragTransform {
    /// Chain multiple transforms in sequence.
    static func sequence(_ transforms: [DragTransform]) -> DragTransform {
        DragTransform { pos in
            transforms.reduce(pos) { $1($0) }
        }
    }

    /// Chain transforms using builder syntax.
    static func sequence(@ListBuilder<DragTransform> _ build: () -> [DragTransform]) -> DragTransform {
        sequence(build())
    }

}
