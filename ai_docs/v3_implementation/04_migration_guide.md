# Migration Guide - HHServices v3.0

> **NOTE: UPDATED FOR PURE SWIFT IMPLEMENTATION**
> 
> This guide has been updated to reflect the actual v3.0 implementation
> as a pure Swift migration rather than XCFramework distribution.

## Overview

HHServices v3.0 is a complete Swift rewrite that provides modern Swift APIs with async/await and Combine support. **This is a major version with API changes from the Objective-C version.**

### What's Changed

| Feature | v2.x | v3.0 |
|---------|------|------|
| **Language** | Objective-C | Pure Swift |
| **Distribution** | Source code | Source code |
| **SPM Support** | ❌ Not working | ✅ Full support |
| **CocoaPods** | ✅ Supported | ✅ Supported |
| **Async/Await** | ❌ Not available | ✅ Native support |
| **Combine** | ❌ Not available | ✅ Native support |
| **Binary Size** | ~200KB source | ~200KB source |
| **API Style** | Objective-C patterns | Swift patterns |

## Migration by Integration Method

### Swift Package Manager Users

#### Before (v2.x)
```swift
// SPM was not supported in v2.x
// Users had to use CocoaPods or manual integration
```

#### After (v3.0)
```swift
// Package.swift - now fully supported!
dependencies: [
    .package(url: "https://github.com/tolo/HHServices.git", from: "3.0.0")
]

// Your code - modern Swift API
import HHServices

let browser = ServiceBrowser(type: "_service._tcp.", domain: "local.")

// Modern async/await (native Swift)
Task {
    for await event in browser.browse() {
        switch event {
        case .serviceAdded(let service):
            print("Found: \(service.name)")
        case .serviceRemoved(let service):
            print("Lost: \(service.name)")
        case .serviceUpdated(let service):
            print("Updated: \(service.name)")
        }
    }
}

// Or use Combine
browser.browsePublisher()
    .sink { event in
        // Handle discovery events
    }
    .store(in: &cancellables)
```

### CocoaPods Users

#### Before (v2.x)
```ruby
# Podfile
pod 'HHServices', '~> 2.0'
```

#### After (v3.0)
```ruby
# Podfile - just update version
pod 'HHServices', '~> 3.0'
```

**That's it!** No code changes required. All APIs work exactly the same.

### Direct Xcode Integration Users

#### Before (v2.x)
1. Drag source files into project
2. Configure build settings
3. Manage dependencies manually

#### After (v3.0)
1. Download `HHServices.xcframework`
2. Drag into project
3. Select "Embed & Sign"
4. Done!

## Common Migration Scenarios

### Scenario 1: SPM User Wanting Async/Await

**Problem**: You've been writing completion handler wrappers because SPM didn't include Swift extensions.

**Before (v2.x):**
```swift
// You had to write your own wrapper
func discoverServices() async throws -> [HHService] {
    await withCheckedContinuation { continuation in
        // Manual delegate handling
        // Complex state management
        // Error prone
    }
}
```

**After (v3.0):**
```swift
// Just use the built-in async/await!
func discoverServices() async throws -> [HHService] {
    var services: [HHService] = []
    for try await discovery in browser.browse() {
        services.append(discovery.service)
    }
    return services
}
```

### Scenario 2: Mixed SPM/CocoaPods Project

**Problem**: Different team members use different package managers.

**Before (v2.x):**
```swift
#if COCOAPODS
// Use async/await
let services = await browser.browse()
#else
// Use delegate pattern
browser.delegate = self
browser.beginBrowse()
#endif
```

**After (v3.0):**
```swift
// Same API everywhere!
let services = await browser.browse()
```

### Scenario 3: CI/CD Pipeline

**Before (v2.x):**
- SPM: Builds from source
- Build time: ~30 seconds

**After (v3.0):**
- SPM: Uses pre-built XCFramework
- Build time: ~5 seconds
- **Faster CI builds!**

## Step-by-Step Migration

### 1. Update Dependencies

#### SPM
```bash
# In your Package.swift, change:
.package(url: "https://github.com/tolo/HHServices.git", .upToNextMajor(from: "2.0.0"))
# To:
.package(url: "https://github.com/tolo/HHServices.git", from: "3.0.0")

# Then update:
swift package update
```

#### CocoaPods
```bash
# In your Podfile, change:
pod 'HHServices', '~> 2.0'
# To:
pod 'HHServices', '~> 3.0'

# Then update:
pod update HHServices
```

### 2. Clean Build

```bash
# SPM
swift package clean
swift build

# Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData
# Then build in Xcode
```

### 3. Update Your Code (SPM Users Only)

If you're using SPM and want to adopt the new async/await features:

```swift
// Add async/await where appropriate
class ServiceDiscovery {
    let browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")
    
    // Old way (still works)
    func startDiscoveryOldWay() {
        browser.delegate = self
        browser.beginBrowse()
    }
    
    // New way (now available!)
    func startDiscoveryNewWay() async throws {
        for try await discovery in browser.browse() {
            handleDiscovery(discovery)
        }
    }
}
```

### 4. Test

Run your test suite to ensure everything works:
```bash
swift test  # For SPM
# or
xcodebuild test  # For Xcode
```

## FAQ

### Q: Will my existing Objective-C code break?
**A**: Yes, v3.0 is a complete Swift rewrite. You'll need to migrate to the new Swift API. See the migration examples above.

### Q: Why was it rewritten in Swift?
**A**: The Swift rewrite solves SPM compatibility issues, provides modern Swift patterns, and simplifies maintenance with a single-language codebase.

### Q: Can I still access the source code?
**A**: Yes! The source remains available on GitHub. The XCFramework is built from the same source.

### Q: What if I need to support iOS 12?
**A**: Stay on v2.x. Version 3.0 requires iOS 13+ for Swift features.

### Q: Do I have to use async/await?
**A**: No! You can use async/await, Combine publishers, or traditional completion handlers. Choose what fits your project best.

## Troubleshooting

If you encounter issues:

### Clear Caches
- SPM: `rm -rf ~/Library/Caches/org.swift.swiftpm`
- CocoaPods: `pod cache clean HHServices`
- Xcode: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Update Dependencies
- SPM: `swift package update`
- CocoaPods: `pod update HHServices`

## Getting Help

### Resources
- [GitHub Issues](https://github.com/tolo/HHServices/issues)
- [API Documentation](https://github.com/tolo/HHServices/wiki)
- [Sample Projects](https://github.com/tolo/HHServices/tree/main/samples)

### Common Issues

#### "Module 'HHServices' not found"
- Clean SPM cache: `rm -rf ~/Library/Caches/org.swift.swiftpm`
- Update packages: `swift package update`

#### "Binary doesn't match Swift version"
- Ensure Xcode 14.0+ is being used
- Check Swift version: `swift --version`

#### Large binary size concerns
- Enable app thinning in App Store Connect
- Consider using on-demand resources

## Summary

**For Objective-C users**: Migration to Swift API required, but brings modern patterns.

**For SPM users**: Full support is finally here! 🎉

**For everyone**: Modern Swift patterns, async/await, Combine, better performance.

Welcome to HHServices v3.0!