// swift-tools-version:5.3
// Development Package.swift for testing with source files

import PackageDescription

let package = Package(
    name: "HHServices",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "HHServices",
            targets: ["HHServices", "HHServicesSwift"]),
    ],
    dependencies: [],
    targets: [
        // Source-based targets for development and testing
        .target(
            name: "HHServices",
            dependencies: [],
            path: "HHServices",
            exclude: ["HHServices+Swift.swift"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .define("_Nullable", to: "__nullable"),
                .define("_Nonnull", to: "__nonnull")
            ]
        ),
        .target(
            name: "HHServicesSwift",
            dependencies: ["HHServices"],
            path: "HHServices",
            sources: ["HHServices+Swift.swift"]
        ),
        .testTarget(
            name: "HHServicesTests",
            dependencies: ["HHServices", "HHServicesSwift"],
            path: "Tests"
        ),
    ]
)