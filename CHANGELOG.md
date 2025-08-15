# Changelog

All notable changes to HHServices will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-08-14

### Added
- Complete Swift rewrite - 100% pure Swift implementation
- Native async/await support without wrappers
- Full type safety with Swift's type system
- Improved error handling with typed errors
- AsyncStream-based service discovery
- Actor-based concurrency safety

### Changed
- **BREAKING**: Complete API redesign in Swift
- **BREAKING**: Minimum deployment target iOS 13.0
- Migrated from Objective-C to Swift
- Source distribution (no more binary frameworks)
- Simplified SPM integration

### Removed
- Objective-C implementation files
- Complex mixed-language build issues
- Need for XCFramework distribution

### Technical Details
- ~1,500 lines of modern Swift code
- Zero external dependencies
- Native Swift concurrency patterns
- Full Sendable conformance for thread safety

### Migration from v2.x
- API has changed significantly due to Swift migration
- Update imports to `import HHServices`
- See migration examples in README

## [2.1.0] - 2025-08-12

### Added
- Swift Package Manager support with full Objective-C compatibility
- Modern Swift extensions with async/await support (iOS 13+)
- Combine publishers for reactive programming (iOS 13+)
- Comprehensive test suite (`Tests/HHServicesTests.m`)
- Privacy manifest file (`PrivacyInfo.xcprivacy`) for iOS 17+
- Local Network privacy documentation (`LOCAL_NETWORK_PRIVACY.md`)
- Migration guide from NSNetService (`MIGRATION_GUIDE.md`)
- Swift wrapper file (`HHServices+Swift.swift`) with modern API

### Changed
- Updated minimum deployment target to iOS 13.0 and tvOS 13.0
- Modernized README with badges, clear use cases, and installation instructions
- Enhanced documentation with iOS 14+ privacy requirements

### Security
- Added proper handling for Local Network permission denial (error -65570)
- Included privacy manifest for iOS 17+ compliance

## [2.0.1] - 2018-01-17

### Fixed
- Removed debug code
- Various stability improvements

## [2.0.0] - 2016-09-10

### Added
- ARC (Automatic Reference Counting) support
- IPv6 support (supporting both `sockaddr_in` and `sockaddr_in6` addresses)
- `moreComing` parameter to `serviceDidResolve` method in `HHServiceDelegate`
- Nullability annotations for better Swift interoperability
- CocoaPods support
- Support for restricting service discovery and publishing to Bluetooth only
- Support for specific interface index selection
- Class `HHAddressInfo` to represent resolved address information

### Changed
- Major API changes in `HHService` class related to resolving host names and addresses
- Method and property changes for better clarity and consistency

### Fixed
- WiFi performance degradation when using P2P (can now use Bluetooth-only mode)

## [1.0.0] - 2012

### Added
- Initial release
- Low-level DNS-SD (Bonjour) service discovery
- Service publishing via `HHServicePublisher`
- Service browsing via `HHServiceBrowser`
- Service resolution via `HHService`
- Bluetooth P2P support on iOS 5+
- Alternative to NSNetService for Bluetooth networking

### Background
This framework was created when iOS 5 removed Bluetooth networking support from NSNetService, forcing developers to use low-level DNSService* (dns-sd) APIs for Bluetooth P2P connectivity.
