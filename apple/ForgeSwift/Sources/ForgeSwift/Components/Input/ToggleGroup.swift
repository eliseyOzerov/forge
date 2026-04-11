//
//  ToggleGroup.swift
//  ForgeSwift
//
//  TODO: coordinates selection across multiple child toggles. Two
//  flavors: single-select (radio-like — selecting one deselects
//  others) and multi-select (checkbox-like — any combination).
//  Parent ModelView that holds the selected id(s) and passes a
//  binding down to each child toggle.
//

public struct ToggleGroup: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: ToggleGroup")
    }
}
