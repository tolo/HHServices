// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HHServices",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HHServices",
            targets: ["HHServices"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // No external dependencies - pure Swift with system frameworks only
    ],
    targets: [
        // Main Swift target
        .target(
            name: "HHServices",
            dependencies: [],
            path: "Sources/HHServices"
        ),
        .testTarget(
            name: "HHServicesTests",
            dependencies: ["HHServices"],
            path: "Tests"
        ),
    ]
)