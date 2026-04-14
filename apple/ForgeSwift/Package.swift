// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ForgeSwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ForgeSwift",
            targets: ["ForgeSwift"]),
    ],
    targets: [
        .target(
            name: "ForgeSwift"),
        .testTarget(
            name: "ForgeSwiftTests",
            dependencies: ["ForgeSwift"]
        ),
    ]
)
