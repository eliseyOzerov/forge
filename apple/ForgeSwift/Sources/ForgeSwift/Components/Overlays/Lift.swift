//
//  Lift.swift
//  ForgeSwift
//
//  Lifts a child into the router stack above its current route.
//  The slot stays in the layout; the lifted copy is a non-opaque
//  route inserted without animation. All visual transitions are
//  the caller's responsibility.
//
//  ```swift
//  Lift(lifted: $isLifted) { lifted in
//      MyCard()
//  }
//  ```
//

#if canImport(UIKit)
import UIKit

// MARK: - Lift

public struct Lift: ModelView {
    public let lifted: Binding<Bool>
    public let builder: @MainActor (Bool) -> any View

    public init(
        lifted: Binding<Bool>,
        @ChildBuilder builder: @escaping @MainActor (Bool) -> any View
    ) {
        self.lifted = lifted
        self.builder = builder
    }

    public func model(context: ViewContext) -> LiftModel { LiftModel(context: context) }
    public func builder(model: LiftModel) -> LiftBuilder { LiftBuilder(model: model) }
}

// MARK: - LiftOverlay

struct LiftOverlay: BuiltView, Route {
    let content: @MainActor () -> any View
    let slotRect: Observable<Rect>

    var opaque: Bool { false }
    var duration: Double { 0 }

    func build(context: ViewContext) -> any View {
        let rect = context.watch(slotRect)
        return Box(BoxStyle(
            .fill,
            padding: Padding(top: rect.y, leading: rect.x),
            alignment: .topLeft
        )) {
            Box(.fixed(rect.width, rect.height)) {
                content()
            }
        }
    }
}

// MARK: - LiftModel

public final class LiftModel: ViewModel<Lift> {
    let slotRect = Observable(Rect.zero)
    private var isLifted = false

    public override func didInit(view: Lift) {
        super.didInit(view: view)
        if view.lifted.value { show() }
    }

    public override func didUpdate(newView: Lift) {
        super.didUpdate(newView: newView)
        if newView.lifted.value && !isLifted {
            show()
        } else if !newView.lifted.value && isLifted {
            hide()
        }
    }

    public override func didDispose() {
        if isLifted { hide() }
        super.didDispose()
    }

    private func show() {
        guard !isLifted else { return }
        isLifted = true
        guard let router = context.maybeRouter,
              let route = context.maybeRoute else { return }
        let builderFn = view.builder
        let overlay = LiftOverlay(
            content: { builderFn(true) },
            slotRect: slotRect
        )
        router.insert(above: { r in (r as? RouteHandle)?.index == route.index }, route: overlay)
    }

    private func hide() {
        guard isLifted else { return }
        isLifted = false
        guard let router = context.maybeRouter else { return }
        router.remove(where: { $0 is LiftOverlay }, result: nil, animated: false)
    }
}

// MARK: - LiftBuilder

public final class LiftBuilder: ViewBuilder<LiftModel> {
    public override func build(context: ViewContext) -> any View {
        let content = model.view.builder(false)
        return RectReporter(onRect: { [weak model] rect in
            model?.slotRect.value = rect
        }, content: content)
    }
}

#endif
