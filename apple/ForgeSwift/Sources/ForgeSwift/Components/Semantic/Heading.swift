//
//  Heading.swift
//  ForgeSwift
//
//  TODO: styled Text for headings. Probably a ComposedView wrapping
//  a Text with preset font weight/size/color based on a level
//  (h1/h2/h3 or .largeTitle/.title/.headline).
//  Props: text content, level.
//

public struct Heading: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Heading")
    }
}
