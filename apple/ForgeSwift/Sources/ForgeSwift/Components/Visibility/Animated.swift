// MARK: - Animated

/// Implicit animation primitive. Interpolates a `Lerpable` value over
/// time whenever the target changes, rebuilding the child with the
/// current interpolated value each frame.
///
/// ```swift
/// Animated(value: model.progress, animation: .default) { context, value in
///     Box(.frame(.fillWidth.height(.fix(value * 200))).surface(.color(.blue)))
/// }
/// ```
///
/// On first build the value settles immediately (no animation). On
/// subsequent updates, the model captures the current interpolated
/// value as `from` and animates to the new target using a
/// `MotionDriver`. Mid-flight retargets are smooth — animation
/// restarts from wherever the interpolation currently is.
public struct Animated<T: Lerpable & Equatable>: ModelView {
    public let value: T
    public let animation: Animation
    public let content: @MainActor (ViewContext, T) -> any View

    public init(
        value: T,
        animation: Animation = .default,
        content: @escaping @MainActor (ViewContext, T) -> any View
    ) {
        self.value = value
        self.animation = animation
        self.content = content
    }

    public func model(context: ViewContext) -> AnimatedModel<T> { AnimatedModel(context: context) }
    public func builder(model: AnimatedModel<T>) -> AnimatedBuilder<T> { AnimatedBuilder(model: model) }
}

// MARK: - Model

public final class AnimatedModel<T: Lerpable & Equatable>: ViewModel<Animated<T>> {
    private var from: T!
    private var to: T!
    private let driver = MotionDriver()

    var current: T {
        let t = view.animation.apply(driver.value)
        return from.lerp(to: to, t: t)
    }

    public override func didInit(view: Animated<T>) {
        super.didInit(view: view)
        from = view.value
        to = view.value
        watch(driver)
    }

    public override func didUpdate(newView: Animated<T>) {
        let oldTarget = to
        super.didUpdate(newView: newView)

        guard newView.value != oldTarget else { return }

        // Snapshot current interpolated value as the new start
        from = current
        to = newView.value
        driver.duration = Duration(newView.animation.duration)
        driver.seek(to: 0)

        Task { @MainActor in
            await driver.forward()
        }
    }
}

// MARK: - Builder

public final class AnimatedBuilder<T: Lerpable & Equatable>: ViewBuilder<AnimatedModel<T>> {
    public override func build(context: ViewContext) -> any View {
        model.view.content(context, model.current)
    }
}
