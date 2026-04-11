//
//  PlatformBuilder.swift
//  ForgeSwift
//
//  TODO: conditional rendering based on platform / form factor.
//  Lets users provide different content for iOS / macOS / iPad /
//  tvOS / compact vs regular size classes. Selects the right
//  branch at build time and delegates to it.
//

public struct PlatformBuilder: ComposedView {
    public init() {}

    public func build(context: BuildContext) -> any View {
        Text("TODO: PlatformBuilder")
    }
}
