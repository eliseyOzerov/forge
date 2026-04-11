//
//  ContextMenu.swift
//  ForgeSwift
//
//  TODO: long-press menu over a source view. Backed by
//  UIContextMenuInteraction on iOS 13+. Probably best modeled as
//  a modifier on the source view rather than a standalone
//  component — you attach a menu to something, not drop a menu
//  into the tree.
//

public struct ContextMenu: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: ContextMenu")
    }
}
