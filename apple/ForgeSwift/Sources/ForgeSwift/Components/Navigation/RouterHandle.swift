//
//  RouterHandle.swift
//  ForgeSwift
//
//  The imperative driver exposed to descendants via ctx.router.
//  Owns two state layers:
//
//    - declarative: the most recent output of the Router's route
//      builder closure. Rebuilt on every Router update; no identity
//      preserved except via Route.Hashable.
//
//    - imperative: a list of insertions applied on top of declarative.
//      Each insertion stores a primary anchor (another route's id) and
//      a fallback chain (snapshot of route ids in the stack at insertion
//      time) so it can slide to a surviving neighbor if its anchor
//      leaves, and reattach if the anchor returns later.
//
//  resolvedStack() folds imperatives into declarative on each read.
//  On any mutation the handle calls onChange, which triggers the host
//  (RouterHost) to diff the new stack into UINavigationController.
//

import Foundation

// MARK: - RouterHandle

@MainActor public final class RouterHandle {
    /// Called after any state change that requires the host to
    /// re-diff the UINavigationController stack.
    var onChange: (() -> Void)?

    /// Most recent declarative sequence from the Router's builder.
    /// Updated by RouterModel on init/update.
    fileprivate(set) var declarative: [AnyRoute] = []

    /// Imperative insertions, in the order they were made. Earlier
    /// insertions can anchor later ones (chaining).
    fileprivate(set) var imperative: [Insertion] = []

    public init() {}

    // MARK: - Insertion

    struct Insertion {
        let route: AnyRoute
        let anchor: Anchor
        let side: Side
        /// Route ids in the resolved stack at insertion time, in order.
        /// Used to find a surviving fallback when the primary anchor
        /// is missing on a future resolve.
        let fallback: [AnyHashable]
    }

    enum Anchor {
        case start
        case end
        case route(AnyHashable)
    }

    public enum Side { case before, after }

    // MARK: - Declarative sync

    /// Called by RouterModel when the Router's builder re-evaluates.
    /// Replaces the declarative list and notifies the host.
    func setDeclarative(_ routes: [AnyRoute]) {
        declarative = routes
        onChange?()
    }

    // MARK: - Imperative API

    /// Push a route onto the end of the resolved stack. Anchors to the
    /// current top; if the stack is empty, anchors to .start.
    public func push<R: Route>(_ route: R) {
        let current = resolvedStack
        let anchor: Anchor = current.last.map { .route($0.id) } ?? .start
        let side: Side = .after
        appendInsertion(AnyRoute(route), anchor: anchor, side: side, current: current)
    }

    /// Insert a route immediately after the given anchor route. If the
    /// anchor is not currently in the stack, the new route is inserted
    /// at the end; it will relocate next to the anchor if the anchor
    /// appears in a future resolve.
    public func insert<R: Route, A: Route>(_ route: R, after anchor: A) {
        let current = resolvedStack
        appendInsertion(
            AnyRoute(route),
            anchor: .route(AnyHashable(anchor)),
            side: .after,
            current: current
        )
    }

    /// Insert a route immediately before the given anchor route.
    public func insert<R: Route, A: Route>(_ route: R, before anchor: A) {
        let current = resolvedStack
        appendInsertion(
            AnyRoute(route),
            anchor: .route(AnyHashable(anchor)),
            side: .before,
            current: current
        )
    }

    /// Insert a route at the given index in the current resolved stack.
    /// Anchors to the route at (index - 1) with side .after, or to
    /// .start if index == 0.
    public func insert<R: Route>(_ route: R, at index: Int) {
        let current = resolvedStack
        let clamped = max(0, min(index, current.count))
        let anchor: Anchor
        let side: Side
        if clamped == 0 {
            anchor = .start
            side = .after
        } else {
            anchor = .route(current[clamped - 1].id)
            side = .after
        }
        appendInsertion(AnyRoute(route), anchor: anchor, side: side, current: current)
    }

    /// Pop the top imperative route. Declarative routes are owned by
    /// the builder — to remove them, the caller must update the state
    /// their declarative closure reads.
    public func pop() {
        guard !imperative.isEmpty else { return }
        imperative.removeLast()
        onChange?()
    }

    /// Remove all imperative routes. Leaves the declarative list
    /// untouched.
    public func popToRoot() {
        guard !imperative.isEmpty else { return }
        imperative.removeAll()
        onChange?()
    }

    /// Replace the top of the resolved stack. If the top is imperative,
    /// replaces it in place; if the top is declarative, adds a new
    /// imperative route after it.
    public func replaceTop<R: Route>(with route: R) {
        if !imperative.isEmpty {
            imperative.removeLast()
        }
        push(route)
    }

    /// Wholesale replace the imperative layer. Useful for "sign out →
    /// reset navigation" flows where you want to reset the stack to
    /// whatever the declarative layer currently says.
    public func setImperative(_ routes: [any Route]) {
        imperative.removeAll()
        for route in routes {
            push(route)
        }
    }

    // MARK: - Resolve

    /// The stack the host should render. Evaluated on every read.
    /// Declarative first, then imperative insertions folded in by
    /// their anchor + fallback rules.
    public var resolvedStack: [AnyRoute] {
        var result = declarative
        for insertion in imperative {
            foldIn(insertion, into: &result)
        }
        return result
    }

    // MARK: - Internals

    private func appendInsertion(
        _ route: AnyRoute,
        anchor: Anchor,
        side: Side,
        current: [AnyRoute]
    ) {
        let insertion = Insertion(
            route: route,
            anchor: anchor,
            side: side,
            fallback: current.map { $0.id }
        )
        imperative.append(insertion)
        onChange?()
    }

    private func foldIn(_ insertion: Insertion, into stack: inout [AnyRoute]) {
        switch insertion.anchor {
        case .start:
            stack.insert(insertion.route, at: 0)
        case .end:
            stack.append(insertion.route)
        case .route(let anchorId):
            let presentIds = Set(stack.map { $0.id })
            let targetId = presentIds.contains(anchorId)
                ? anchorId
                : walkFallback(insertion.fallback, primary: anchorId, side: insertion.side, present: presentIds)
            if let targetId, let idx = stack.firstIndex(where: { $0.id == targetId }) {
                let insertAt = insertion.side == .after ? idx + 1 : idx
                stack.insert(insertion.route, at: insertAt)
            } else {
                // Nothing from the fallback survives — snap to the
                // edge implied by side.
                let insertAt = insertion.side == .after ? stack.count : 0
                stack.insert(insertion.route, at: insertAt)
            }
        }
    }

    private func walkFallback(
        _ fallback: [AnyHashable],
        primary: AnyHashable,
        side: Side,
        present: Set<AnyHashable>
    ) -> AnyHashable? {
        guard let primaryIdx = fallback.firstIndex(of: primary) else { return nil }
        switch side {
        case .after:
            // Walk backward from primary looking for a surviving
            // predecessor — the insertion wants to sit after something,
            // so a predecessor is the closest "still correct" anchor.
            for i in stride(from: primaryIdx - 1, through: 0, by: -1) {
                if present.contains(fallback[i]) { return fallback[i] }
            }
        case .before:
            // Walk forward for surviving successor.
            for i in (primaryIdx + 1)..<fallback.count {
                if present.contains(fallback[i]) { return fallback[i] }
            }
        }
        return nil
    }
}
