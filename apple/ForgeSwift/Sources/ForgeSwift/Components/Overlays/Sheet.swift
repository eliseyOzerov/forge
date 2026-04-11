//
//  Sheet.swift
//  ForgeSwift
//
//  TODO: UISheetPresentationController-based bottom sheet. Same
//  architectural question as Alert — sheets are presentations, not
//  subviews. Probably modeled as a modifier (.sheet(isPresented:
//  content:)) rather than a standalone View.
//
//  Props: isPresented binding, detents (medium/large), prefers
//  grabber visible, content builder.
//

public struct Sheet: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: Sheet")
    }
}
