import Foundation

// MARK: - DismissPhase

/// Current phase of a swipe-to-dismiss gesture.
public enum DismissPhase: Sendable {
    case idle
    case dragging
    case dismissing
    case dismissed
}

// MARK: - DismissThreshold

/// Distance and velocity thresholds that trigger a swipe dismiss.
public struct DismissThreshold {
    /// Fractional distance (0→1) past which a stationary release triggers dismiss.
    public var distance: Double

    /// Minimum fling velocity in points/sec to trigger dismiss regardless of position.
    public var velocity: Double

    public init(distance: Double = 0.5, velocity: Double = 800) {
        self.distance = distance
        self.velocity = velocity
    }
}

// MARK: - Dismissible

/// A gesture wrapper that tracks swipe-to-dismiss progress.
///
/// Progress is fractional: 0 = resting, 1 = fully dismissed (offset
/// equals the child's size along the swipe axis). The builder
/// receives progress every frame and decides how to render the child.
///
/// ```swift
/// Dismissible(
///     value: $progress,
///     edge: .trailing,
///     threshold: DismissThreshold(distance: 0.4),
///     onUpdate: { value, phase in print(value, phase) }
/// ) { ctx, progress in
///     MyListItem()
///         .effect { $0.offset(progress, fractional: true) }
/// }
/// ```
#if canImport(UIKit)
public struct Dismissible: ModelView {
    public let value: Binding<Double>
    public let edge: Edge?
    public let duration: Double
    public let threshold: DismissThreshold
    public let curve: Curve
    public let onUpdate: (@MainActor (Double, DismissPhase) -> Void)?
    public let builder: @MainActor (ViewContext, Double) -> any View

    public init(
        value: Binding<Double>,
        edge: Edge? = nil,
        duration: Double = 0.35,
        threshold: DismissThreshold = DismissThreshold(),
        curve: Curve = .easeOut,
        onUpdate: (@MainActor (Double, DismissPhase) -> Void)? = nil,
        builder: @escaping @MainActor (ViewContext, Double) -> any View
    ) {
        self.value = value
        self.edge = edge
        self.duration = duration
        self.threshold = threshold
        self.curve = curve
        self.onUpdate = onUpdate
        self.builder = builder
    }

    public func model(context: ViewContext) -> DismissibleModel { DismissibleModel(context: context) }
    public func builder(model: DismissibleModel) -> DismissibleBuilder { DismissibleBuilder(model: model) }
}

// MARK: - Model

/// Tracks drag state and drives the dismiss animation.
public final class DismissibleModel: ViewModel<Dismissible> {
    private(set) var phase: DismissPhase = .idle

    private let driver = MotionDriver(duration: Duration(0.35))
    private var animFrom: Double = 0
    private var animTo: Double = 0
    var containerSize: Size = .zero
    private var dragStart: Vec2 = .zero
    private var dragAxis: Edge?

    public override func didInit(view: Dismissible) {
        super.didInit(view: view)
        driver.duration = Duration(view.duration)
        watch(driver)
    }

    /// Current visual progress, accounting for animation.
    var displayProgress: Double {
        if driver.isRunning {
            let eased = view.curve(driver.value)
            return animFrom + (animTo - animFrom) * eased
        }
        return view.value.value
    }

    // MARK: - Gesture

    func handleDragStart(at position: Vec2) {
        guard phase == .idle else { return }
        dragStart = position
        dragAxis = nil
        setPhase(.dragging)
        print("[Dismissible] START pos=\(position)")
    }

    func handleDragUpdate(at position: Vec2) {
        guard phase == .dragging else { return }
        let delta = position - dragStart
        // Resolve axis on first significant move if edge is nil
        if dragAxis == nil {
            if let edge = view.edge {
                dragAxis = edge
            } else {
                let absX = abs(delta.x)
                let absY = abs(delta.y)
                guard absX > 10 || absY > 10 else { return }
                if absX > absY {
                    dragAxis = delta.x > 0 ? .trailing : .leading
                } else {
                    dragAxis = delta.y > 0 ? .bottom : .top
                }
            }
        }

        guard let axis = dragAxis else { return }
        let raw = rawProgress(for: delta, axis: axis)
        let clamped = min(max(raw, 0), 1)
        print("[Dismissible] UPDATE delta=\(delta) axis=\(axis) raw=\(raw) clamped=\(clamped) containerSize=\(containerSize)")
        rebuild {
            view.value.value = clamped
        }
        fireUpdate(clamped)
    }

    func handleDragEnd(velocity: Vec2) {
        guard phase == .dragging, let axis = dragAxis else {
            print("[Dismissible] END skipped phase=\(phase) axis=\(String(describing: dragAxis))")
            snapBack()
            return
        }

        let vel = axisVelocity(velocity, axis: axis)
        let shouldDismiss = view.value.value >= view.threshold.distance || vel >= view.threshold.velocity
        print("[Dismissible] END vel=\(vel) value=\(view.value.value) threshold=\(view.threshold.distance) shouldDismiss=\(shouldDismiss)")

        if shouldDismiss {
            animateTo(1)
        } else {
            snapBack()
        }
    }

    func handleDragCancel() {
        print("[Dismissible] CANCEL")
        snapBack()
    }

    // MARK: - Animation

    private func animateTo(_ target: Double) {
        let remaining = abs(target - view.value.value)
        let scaledDuration = view.duration * remaining
        driver.duration = Duration(max(scaledDuration, 0.1))

        animFrom = view.value.value
        animTo = target
        driver.seek(to: 0)

        let isDismissing = target >= 1
        if isDismissing { setPhase(.dismissing) }

        Task { [weak self] in
            guard let self else { return }
            await driver.forward()
            rebuild {
                view.value.value = target
                setPhase(isDismissing ? .dismissed : .idle)
            }
        }
    }

    private func snapBack() {
        if view.value.value > 0 {
            animateTo(0)
        } else {
            setPhase(.idle)
        }
    }

    private func setPhase(_ newPhase: DismissPhase) {
        phase = newPhase
        fireUpdate(displayProgress)
    }

    private func fireUpdate(_ value: Double) {
        view.onUpdate?(value, phase)
    }

    // MARK: - Helpers

    private func axisSize(_ axis: Edge) -> Double {
        switch axis {
        case .leading, .trailing: return max(containerSize.width, 1)
        case .top, .bottom: return max(containerSize.height, 1)
        }
    }

    private func rawProgress(for delta: Vec2, axis: Edge) -> Double {
        let size = axisSize(axis)
        switch axis {
        case .trailing: return delta.x / size
        case .leading: return -delta.x / size
        case .bottom: return delta.y / size
        case .top: return -delta.y / size
        }
    }

    private func axisVelocity(_ velocity: Vec2, axis: Edge) -> Double {
        switch axis {
        case .trailing: return velocity.x
        case .leading: return -velocity.x
        case .bottom: return velocity.y
        case .top: return -velocity.y
        }
    }
}

// MARK: - Builder

/// Wraps the dismissible content in a drag gesture and layout reader.
public final class DismissibleBuilder: ViewBuilder<DismissibleModel> {
    public override func build(context: ViewContext) -> any View {
        let model = self.model
        let progress = model.displayProgress
        let content = model.view.builder(context, progress)

        return LayoutReader { [weak model] size in
            guard let model else { return EmptyView() }
            model.containerSize = Size(Double(size.width), Double(size.height))

            return Gesture(
                drag: DragConfig(
                    onStart: { [weak model] e in
                        model?.handleDragStart(at: e.position.local)
                    },
                    onUpdate: { [weak model] e in
                        model?.handleDragUpdate(at: e.position.local)
                    },
                    onEnd: { [weak model] e in
                        model?.handleDragEnd(velocity: e.velocity)
                    },
                    onCancel: { [weak model] in
                        model?.handleDragCancel()
                    }
                )
            ) {
                content
            }
        }
    }
}
#endif
