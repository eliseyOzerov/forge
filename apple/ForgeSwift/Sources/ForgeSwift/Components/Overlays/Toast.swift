//
//  Toast.swift
//  ForgeSwift
//
//  TODO: UIKit has no native toast — implement as a custom UIView
//  added to the key window, auto-dismissing after a duration.
//  Unlike Alert/Sheet, toasts don't need a presenting
//  UIViewController — they can be added directly to the window.
//
//  Props: message, duration, optional icon, optional action button,
//  position (top/bottom).
//

public struct Toast: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Toast")
    }
}
