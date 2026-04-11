//
//  Indicator.swift
//  ForgeSwift
//
//  TODO: base indicator type for progress-like visual feedback.
//  Loader, Progress, and Skeleton are specializations. If the
//  concrete variants cover the needed cases, Indicator may stay
//  as an abstract parent and never be instantiated directly.
//

public struct Indicator: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Indicator")
    }
}
