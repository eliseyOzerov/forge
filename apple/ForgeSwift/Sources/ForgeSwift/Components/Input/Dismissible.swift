import Foundation

// MARK: - DismissPhase

public enum DismissPhase: Sendable {
    case idle
    case dragging
    case dismissing
    case dismissed
}

// MARK: - DismissThreshold

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
/// Dismissible(edge: .trailing, threshold: DismissThreshold(distance: 0.4)) { ctx, progress in
///     MyListItem()
///         .offset(x: progress * ctx.size.width)
///         .opacity(1 - progress)
/// }
/// ```
public struct Dismissible: ModelView {
    public let edge: Edge?
    public let duration: Double
    public let threshold: DismissThreshold
    public let curve: Curve
    public let builder: @MainActor (ViewContext, Double) -> any View

    public init(
        edge: Edge? = nil,
        duration: Double = 0.35,
        threshold: DismissThreshold = DismissThreshold(),
        curve: Curve = .easeOut,
        builder: @escaping @MainActor (ViewContext, Double) -> any View
    ) {
        self.edge = edge
        self.duration = duration
        self.threshold = threshold
        self.curve = curve
        self.builder = builder
    }

    public func model(context: ViewContext) -> DismissibleModel { DismissibleModel(context: context) }
    public func builder(model: DismissibleModel) -> DismissibleBuilder { DismissibleBuilder(model: model) }
}

// MARK: - Model

public final class DismissibleModel: ViewModel<Dismissible> {
    public let phase = Observable<DismissPhase>(.idle)
    public let progress = Observable<Double>(0)

    private let driver = MotionDriver(duration: Duration(0.35))
    private var animFrom: Double = 0
    private var animTo: Double = 0
    private var containerSize: Size = .zero
    private var dragStart: Vec2 = .zero
    private var dragAxis: Edge?

    public override func didInit(view: Dismissible) {
        super.didInit(view: view)
        driver.duration = Duration(view.duration)
        watch(driver)
        watch(progress)
    }

    /// Current visual progress, accounting for animation.
    var displayProgress: Double {
        if driver.isRunning {
            let eased = view.curve(driver.value)
            return animFrom + (animTo - animFrom) * eased
        }
        return progress.value
    }

    // MARK: - Gesture

    func handleDragStart(at position: Vec2) {
        guard phase.value == .idle else { return }
        dragStart = position
        dragAxis = nil
        phase.value = .dragging
    }

    func handleDragUpdate(at position: Vec2) {
        guard phase.value == .dragging else { return }
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
        rebuild { progress.value = clamped }
    }

    func handleDragEnd(velocity: Vec2) {
        guard phase.value == .dragging, let axis = dragAxis else {
            snapBack()
            return
        }

        let vel = axisVelocity(velocity, axis: axis)
        let shouldDismiss = progress.value >= view.threshold.distance || vel >= view.threshold.velocity

        if shouldDismiss {
            animateTo(1)
        } else {
            snapBack()
        }
    }

    func handleDragCancel() {
        snapBack()
    }

    func updateSize(_ size: Size) {
        containerSize = size
    }

    // MARK: - Animation

    private func animateTo(_ target: Double) {
        let remaining = abs(target - progress.value)
        let scaledDuration = view.duration * remaining
        driver.duration = Duration(max(scaledDuration, 0.1))

        animFrom = progress.value
        animTo = target
        driver.seek(to: 0)

        let isDismissing = target >= 1
        if isDismissing { phase.value = .dismissing }

        Task { [weak self] in
            guard let self else { return }
            await driver.forward()
            rebuild {
                progress.value = target
                phase.value = isDismissing ? .dismissed : .idle
            }
        }
    }

    private func snapBack() {
        if progress.value > 0 {
            animateTo(0)
        } else {
            phase.value = .idle
        }
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

public final class DismissibleBuilder: ViewBuilder<DismissibleModel> {
    public override func build(context: ViewContext) -> any View {
        let model = self.model
        let progress = model.displayProgress
        let content = model.view.builder(context, progress)
        return Provided(model.phase, model.progress) {
            DismissibleLeaf(model: model, content: content)
        }
    }
}

// MARK: - Leaf

struct DismissibleLeaf: LeafView {
    let model: DismissibleModel
    let content: any View
    func makeRenderer() -> Renderer { DismissibleRenderer(view: self) }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

final class DismissibleRenderer: Renderer {
    private weak var dismissView: DismissibleView?
    private var view: DismissibleLeaf
    private var childNode: Node?

    init(view: DismissibleLeaf) { self.view = view }

    func update(from newView: any View) {
        guard let leaf = newView as? DismissibleLeaf, let dismissView else { return }
        view = leaf
        dismissView.model = leaf.model

        if let existing = childNode, existing.canUpdate(to: leaf.content) {
            existing.update(from: leaf.content)
        } else {
            childNode?.platformView?.removeFromSuperview()
            let node = Node.inflate(leaf.content)
            childNode = node
            if let pv = node.platformView {
                dismissView.addSubview(pv)
            }
        }
    }

    func mount() -> PlatformView {
        let v = DismissibleView()
        self.dismissView = v
        v.model = view.model

        let node = Node.inflate(view.content)
        childNode = node
        if let pv = node.platformView {
            v.addSubview(pv)
        }
        return v
    }
}

final class DismissibleView: UIView {
    weak var model: DismissibleModel?
    private var panGesture: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        model?.updateSize(Size(Double(bounds.width), Double(bounds.height)))
        for child in subviews {
            child.frame = bounds
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
        case .ended:
            let vel = gesture.velocity(in: self)
            model?.handleDragEnd(velocity: Vec2(Double(vel.x), Double(vel.y)))
        case .cancelled, .failed:
            model?.handleDragCancel()
        default: break
        }
    }

    override func removeFromSuperview() {
        model?.progress.value = 0
        model?.phase.value = .idle
        super.removeFromSuperview()
    }
}

#endif
