//
//  Transition.swift
//  ForgeSwift
//
//  TODO: generic transition primitive. Attached to a view via a
//  modifier-like wrapper (e.g. `.transition(.fade)` or similar) —
//  the reconciler checks for a transition when a view enters or
//  leaves the tree and runs the corresponding animation. Depends
//  on the exit-animation / zombie infrastructure.
//

public struct Transition: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Transition")
    }
}
