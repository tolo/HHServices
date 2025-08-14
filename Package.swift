// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Check if we're in development mode (for testing)
let isDevelopment = ProcessInfo.processInfo.environment["HHSERVICES_DEV"] != nil

let package: Package

if isDevelopment {
    // Development mode: Use source files for testing
    package = Package(
        name: "HHServices",
        platforms: [
            .iOS(.v13)
        ],
        products: [
            .library(
                name: "HHServices",
                targets: ["HHServices"]),
        ],
        dependencies: [],
        targets: [
            .target(
                name: "HHServices",
                dependencies: [],
                path: "HHServices",
                exclude: ["HHServices+Swift.swift"],
                sources: [
                    "HHService.m",
                    "HHServiceBrowser.m", 
                    "HHServiceDiscoveryOperation.m",
                    "HHServicePublisher.m",
                    "HHServiceValidation.m"
                ],
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath(".")
                ]
            ),
            .testTarget(
                name: "HHServicesTests",
                dependencies: ["HHServices"],
                path: "Tests"
            ),
        ]
    )
} else {
    // Production mode: Use XCFramework for distribution
    package = Package(
        name: "HHServices",
        platforms: [
            .iOS(.v13)
        ],
        products: [
            .library(
                name: "HHServices",
                targets: ["HHServices"]),
        ],
        dependencies: [],
        targets: [
            .binaryTarget(
                name: "HHServices",
                path: "Binary/HHServices.xcframework"
            )
        ]
    )
}