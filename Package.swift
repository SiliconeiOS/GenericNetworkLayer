// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GenericNetworkLayer",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "GenericNetworkLayer",
            targets: ["GenericNetworkLayer"]),
    ],
    targets: [
        .target(
            name: "GenericNetworkLayer"),
        .testTarget(
            name: "GenericNetworkLayerTests",
            dependencies: ["GenericNetworkLayer"]
        ),
    ]
)
