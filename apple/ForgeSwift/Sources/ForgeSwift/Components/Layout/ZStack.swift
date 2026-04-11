//
//  ZStack.swift
//  ForgeSwift
//
//  TODO: z-ordered overlap. ContainerView backed by a plain UIView
//  that uses auto-layout to place each child at the same frame.
//  Children are painted back-to-front in declaration order.
//  Props: alignment (how children are aligned within the container).
//

public struct ZStack: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: ZStack")
    }
}
