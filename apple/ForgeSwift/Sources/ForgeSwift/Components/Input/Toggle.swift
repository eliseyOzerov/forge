//
//  Toggle.swift
//  ForgeSwift
//
//  TODO: generic on/off toggle. Distinct from Switch (which is
//  specifically the iOS switch control) — Toggle is a more
//  abstract "boolean input" that could render differently in
//  different contexts (chip, button, tile, etc.). Might be
//  better modeled as a protocol that concrete toggles conform to.
//

public struct Toggle: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Toggle")
    }
}
