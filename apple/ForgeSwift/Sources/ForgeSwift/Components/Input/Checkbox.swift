//
//  Checkbox.swift
//  ForgeSwift
//
//  TODO: UIKit has no native checkbox — implement as a LeafView
//  backed by a UIButton with checkbox.square.fill / square SF
//  Symbols for the on / off states. Props: isOn binding, label.
//

public struct Checkbox: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Checkbox")
    }
}
