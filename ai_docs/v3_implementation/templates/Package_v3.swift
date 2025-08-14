// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// HHServices v3.0 - Package.swift Template
// This version uses XCFramework binary distribution

import PackageDescription

let package = Package(
    name: "HHServices",
    platforms: [
        // Minimum iOS 13 for async/await and Combine support
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        // Single library product containing full API
        .library(
            name: "HHServices",
            targets: ["HHServices"]
        ),
    ],
    dependencies: [
        // No external dependencies required
    ],
    targets: [
        // Binary target pointing to pre-built XCFramework
        // This includes both Objective-C and Swift code
        .binaryTarget(
            name: "HHServices",
            path: "Binary/HHServices.xcframework"
        ),
        
        // Alternative: For GitHub releases, use URL-based distribution
        // .binaryTarget(
        //     name: "HHServices",
        //     url: "https://github.com/tolo/HHServices/releases/download/v3.0.0/HHServices.xcframework.zip",
        //     checksum: "SHA256_CHECKSUM_HERE"
        // ),
    ]
)

// MARK: - Usage Instructions
//
// After adding this package to your project, you can import and use HHServices:
//
// ```swift
// import HHServices
//
// // Traditional Objective-C API
// let browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")
// browser.delegate = self
// browser.beginBrowse()
//
// // Modern Swift async/await API (NEW in v3.0 for SPM!)
// Task {
//     for try await discovery in browser.browse() {
//         print("Found service: \(discovery.service.name)")
//     }
// }
//
// // Combine API (NEW in v3.0 for SPM!)
// browser.browsePublisher()
//     .sink { completion in
//         // Handle completion
//     } receiveValue: { discovery in
//         print("Found service: \(discovery.service.name)")
//     }
//     .store(in: &cancellables)
// ```