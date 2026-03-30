// swift-tools-version: 6.2

import CompilerPluginSupport
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", from: "602.0.0"),
    ],
    targets: [
        .target(
            name: "StateKit",
            dependencies: ["StateKitMacros"]
        ),
        .macro(
            name: "StateKitMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "StateKitTests",
            dependencies: ["StateKit"]
        ),
    ]
)
