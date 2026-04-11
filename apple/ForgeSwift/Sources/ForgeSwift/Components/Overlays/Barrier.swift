//
//  Barrier.swift
//  ForgeSwift
//
//  TODO: dismissable background behind overlays. A semi-transparent
//  UIView covering the presenting scene; tapping it dismisses the
//  overlay above it. Usually an implementation detail of Modal /
//  Sheet / Drawer rather than a user-facing component, but exposed
//  for custom overlays.
//

public struct Barrier: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Barrier")
    }
}
