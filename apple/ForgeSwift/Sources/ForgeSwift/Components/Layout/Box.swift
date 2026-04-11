//
//  Box.swift
//  ForgeSwift
//
//  TODO: single-child styled container. Box IS a ContainerView with
//  exactly one child — not a "modifier" in the SwiftUI sense. The
//  renderer is a plain UIView that hosts the child subview with
//  constraints and layer properties determined by Box's styling
//  props.
//
//  Styling props (probably bundled into a BoxStyle eventually):
//    - padding: EdgeInsets
//    - alignment: Alignment (how the child sits within the box)
//    - background: Color
//    - border: width + color
//    - cornerRadius: CGFloat
//    - frame: Frame (fixed or min/max width/height)
//    - shadow: offset + radius + color
//    - clip: Bool
//
//  Design question for implementation time: one kitchen-sink Box
//  with many optional props, OR many focused single-child wrappers
//  (Padding, Align, Background, Frame, CornerRadius) that users
//  compose by nesting. Both are ContainerViews with one child; the
//  difference is prop-bundling vs composition. Likely some of both.
//

public struct Box: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Box")
    }
}
