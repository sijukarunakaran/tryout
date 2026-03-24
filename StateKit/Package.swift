// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "StateKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "StateKit",
            targets: ["StateKit"]
        ),
    ],
    targets: [
        .target(
            name: "StateKit"
        ),
        .testTarget(
            name: "StateKitTests",
            dependencies: ["StateKit"]
        ),
    ]
)
