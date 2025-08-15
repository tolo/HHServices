# Technical Design - HHServices v3.0

> **NOTE: ACTUAL IMPLEMENTATION USED PURE SWIFT MIGRATION**
> 
> This document describes the original XCFramework plan. The actual v3.0 release
> was implemented as a 100% Swift migration, which proved to be a superior solution.
> See README.md for the actual implementation details.

## Original Problem Statement

Swift Package Manager (SPM) does not support mixed Objective-C and Swift source files in a single target. This creates an inconsistent API experience:

- **CocoaPods users**: Full API with async/await
- **SPM users**: Objective-C API only
- **Result**: Confusion, poor DX, documentation complexity

## Originally Planned Solution: XCFramework Distribution

### Why XCFramework?

After evaluating multiple approaches:

1. ❌ **Pure Swift rewrite**: Lengthy process, high risk of breaking Bluetooth P2P
2. ❌ **Dual module SPM**: Still requires two imports, complex dependencies
3. ❌ **Drop SPM support**: Alienates growing SPM user base
4. ✅ **XCFramework**: Single import, full API, straightforward implementation

### Architecture Overview

```
┌─────────────────────────────────────────┐
│          HHServices.xcframework         │
├─────────────────────────────────────────┤
│  iOS-arm64/                             │
│    └── HHServices.framework             │
│        ├── Headers/                     │
│        ├── Modules/                     │
│        │   ├── module.modulemap         │
│        │   └── HHServices.swiftmodule/  │
│        └── HHServices (binary)          │
├─────────────────────────────────────────┤
│  iOS-arm64-simulator/                   │
│    └── (same structure)                 │
├─────────────────────────────────────────┤
│  tvOS-arm64/                            │
│    └── (same structure)                 │
└─────────────────────────────────────────┘
```

### Module Structure

The XCFramework contains a single module `HHServices` that includes:

**Objective-C Layer** (unchanged):
- `HHService.{h,m}`
- `HHServiceBrowser.{h,m}`
- `HHServicePublisher.{h,m}`
- `HHServiceDiscoveryOperation.{h,m}`
- `HHServiceValidation.{h,m}`

**Swift Layer** (compiled in):
- `HHServices+Swift.swift` with:
  - Async/await wrappers
  - Combine publishers
  - Swift-friendly error types

### Build Configuration

Required Xcode build settings:

```
BUILD_LIBRARY_FOR_DISTRIBUTION = YES
DEFINES_MODULE = YES
SWIFT_EMIT_MODULE_INTERFACE = YES
SKIP_INSTALL = NO
ONLY_ACTIVE_ARCH = NO
```

### Package Distribution

**Swift Package Manager**:
```swift
.binaryTarget(
    name: "HHServices",
    path: "Binary/HHServices.xcframework"
)
```

**CocoaPods**:
```ruby
s.vendored_frameworks = 'Binary/HHServices.xcframework'
```

## Technical Considerations

### Binary Size

Estimated XCFramework size:
- Per architecture: ~500KB
- Total (4 architectures): ~2MB
- Compressed (GitHub): ~800KB

### ABI Stability

- Swift 5.0+ ABI stable
- Module interface (.swiftinterface) ensures forward compatibility
- Objective-C ABI always stable

### Platform Support

| Platform | Architectures | Status |
|----------|--------------|--------|
| iOS Device | arm64 | ✅ |
| iOS Simulator | arm64, x86_64 | ✅ |
| tvOS Device | arm64 | ✅ |
| tvOS Simulator | arm64, x86_64 | ✅ |
| macOS | - | ❌ Not supported |
| watchOS | - | ❌ Not supported |

### Debugging Experience

- Debug symbols included in framework
- Source maps preserved
- LLDB debugging works normally
- Crash reports show proper symbols

## Risk Analysis

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Build script failure | Low | Medium | Extensive testing, CI validation |
| Binary compatibility issue | Low | High | Use stable compiler, test on multiple Xcode versions |
| Large binary size | Low | Low | Optimize flags, strip unnecessary symbols |
| SPM cache issues | Medium | Low | Clear documentation, version tags |

### Non-Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User confusion | Medium | Medium | Clear migration guide, examples |
| Open source concerns | Low | Low | Maintain source availability, explain rationale |
| Apple policy change | Low | High | Monitor WWDC, have fallback plan |

## Alternatives Considered

### Alternative 1: @_exported Import

```swift
// HHServicesSwift module
@_exported import HHServices
```

**Rejected because**: Still requires separate targets, doesn't fully solve the problem.

### Alternative 2: Conditional Compilation

```swift
#if SWIFT_PACKAGE
// SPM-specific code
#else
// CocoaPods-specific code
#endif
```

**Rejected because**: Maintains API fragmentation, complex to maintain.

### Alternative 3: Wait for Apple

Wait for SPM to support mixed-language targets.

**Rejected because**: No timeline, may never happen, users need solution now.

## Validation Requirements

Before proceeding with implementation:

1. ✅ Verify XCFramework can be built from current project
2. ✅ Confirm Swift extensions are included in framework
3. ✅ Test import in sample SPM project
4. ✅ Validate async/await availability
5. ✅ Check binary size is acceptable
6. ✅ Ensure debugging experience is preserved

## Success Metrics

### Technical Metrics
- Build time: < 5 minutes
- Binary size: < 5MB uncompressed
- API coverage: 100% parity
- Test coverage: > 90%

### User Experience Metrics
- Single import statement
- Zero breaking changes
- Simplified documentation
- Reduced support tickets

## Actual Implementation

Instead of XCFramework distribution, we migrated the entire codebase to Swift:
- **Result**: Pure Swift source distribution
- **Benefits**: Simpler, smaller, better debugging, no binary trust issues
- **Outcome**: Superior solution that completely eliminates SPM limitations

## Original Conclusion

The XCFramework approach was considered the optimal solution that would:
- Solve the immediate problem completely
- Require minimal code changes
- Be implemented efficiently
- Maintain stability and compatibility
- Provide excellent user experience

However, the Swift migration proved to be even better, following the project's KISS principle while delivering more value to users.