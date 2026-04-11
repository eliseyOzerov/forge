//
//  Alert.swift
//  ForgeSwift
//
//  TODO: UIAlertController doesn't fit the LeafView / ContainerView
//  split — alerts aren't subviews, they're modal presentations from
//  a UIViewController. Implementing alerts probably requires a new
//  PresentationNode that walks up to the nearest UIViewController
//  and calls .present(_:animated:) with the configured controller.
//
//  Alternatively, alerts could be modeled as a .alert(isPresented:)
//  modifier on another view, similar to SwiftUI. That's cleaner
//  because alerts are triggered by state changes, not by being
//  placed in the tree at a specific position.
//
//  Props when implemented: title, message, buttons (with roles).
//

public struct Alert: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Alert")
    }
}
