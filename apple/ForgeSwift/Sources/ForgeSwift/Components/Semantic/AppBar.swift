//
//  AppBar.swift
//  ForgeSwift
//
//  TODO: top navigation bar. On UIKit, either a UINavigationBar
//  or a composed HStack with title + action buttons. The former is
//  more native-feeling; the latter is more flexible.
//  Props: title, leading/trailing items, optional back button.
//

public struct AppBar: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: AppBar")
    }
}
