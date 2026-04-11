//
//  Popover.swift
//  ForgeSwift
//
//  TODO: anchored popover attached to a source view. Backed by
//  UIPopoverPresentationController on iPad; falls back to a sheet
//  on iPhone. Needs the source view's frame and the direction the
//  arrow should point.
//

public struct Popover: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Popover")
    }
}
