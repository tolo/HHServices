# Migration Guide - HHServices v3.0

## Overview

HHServices v3.0 introduces XCFramework distribution while maintaining 100% API compatibility with v2.x. This guide helps you migrate from v2.x to v3.0.

## What's Changed

### Distribution Method
- **v2.x**: Source files distributed via SPM/CocoaPods
- **v3.0**: Pre-built XCFramework binary distribution

### Benefits of v3.0
- ✅ Significantly faster build times (no compilation needed)
- ✅ Full async/await and Combine support via SPM
- ✅ Single `import HHServices` includes all features
- ✅ Reduced integration complexity
- ✅ Consistent behavior across all integration methods

## Migration Steps

### Swift Package Manager

#### Step 1: Update Package.swift
```swift
// Old (v2.x)
.package(url: "https://github.com/tolo/HHServices.git", from: "2.1.0")

// New (v3.0)
.package(url: "https://github.com/tolo/HHServices.git", from: "3.0.0")
```

#### Step 2: Clean and Rebuild
```bash
swift package clean
swift build
```

That's it! No code changes needed.

### CocoaPods

#### Step 1: Update Podfile
```ruby
# Old (v2.x)
pod 'HHServices', '~> 2.1'

# New (v3.0)
pod 'HHServices', '~> 3.0'
```

#### Step 2: Update Pods
```bash
pod update HHServices
```

#### Step 3: Update Import Statements (if needed)
If you were importing individual headers:
```objc
// Old (might work but not recommended)
#import "HHService.h"
#import "HHServiceBrowser.h"

// New (recommended)
#import <HHServices/HHServices.h>
```

### Manual Integration

#### Step 1: Remove Old Files
Remove all `.h` and `.m` files from the HHServices directory in your project.

#### Step 2: Add XCFramework
1. Download or build the XCFramework: `Binary/HHServices.xcframework`
2. Drag it into your Xcode project
3. Select "Embed & Sign" in the frameworks settings

#### Step 3: Update Imports
```objc
// Old
#import "HHService.h"

// New
#import <HHServices/HHServices.h>
```

## API Compatibility

### ✅ No Breaking Changes
All existing APIs from v2.x work identically in v3.0:

```objc
// This code works exactly the same in v2.x and v3.0
HHServiceBrowser *browser = [[HHServiceBrowser alloc] initWithType:@"_http._tcp." domain:@"local."];
[browser beginBrowse];
```

### ✅ Swift Extensions Available
With v3.0 via SPM, you automatically get Swift extensions:

```swift
// Async/await (iOS 13+)
for try await discovery in browser.browse() {
    print("Found: \(discovery.service.name)")
}

// Combine (iOS 13+)
browser.browsePublisher()
    .sink { discovery in
        print("Found: \(discovery.service.name)")
    }
```

## Platform Support

### iOS
- ✅ iOS 13.0+ (same as v2.x)
- ✅ Supports iPhone and iPad
- ✅ Simulator and device builds included

### tvOS
- ⚠️ Temporarily removed in v3.0
- Can be re-added if needed (open an issue)

## Troubleshooting

### Issue: "No such module 'HHServices'"
**Solution**: Clean your build folder and derived data:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Issue: Build errors after updating
**Solution**: Ensure you're using Xcode 14.0+ and clean your package cache:
```bash
rm -rf ~/Library/Caches/org.swift.swiftpm
```

### Issue: CocoaPods validation warnings
**Solution**: These are expected and safe to ignore. Use:
```bash
pod install --repo-update
```

## Performance Improvements

### Build Time Comparison
- **v2.x**: ~5-10 seconds (compiling Objective-C files)
- **v3.0**: <1 second (linking pre-built framework)

### App Size Impact
- XCFramework adds approximately 800KB to your app
- This includes both device and simulator architectures
- App Store submission strips unused architectures automatically

## Development Notes

### Testing
If you're developing or contributing to HHServices:
- The main Package.swift uses XCFramework for distribution
- For running tests with `swift test`, use: `HHSERVICES_DEV=1 swift test`
- This switches to source-based compilation for testing
- For production testing, use Xcode: `xcodebuild test -project HHServices.xcodeproj`

### Building from Source
To build your own XCFramework:
```bash
./Scripts/build-xcframework.sh
```

## Support

### Getting Help
- Open an issue on [GitHub](https://github.com/tolo/HHServices/issues)
- Check existing issues for solutions
- Provide your integration method (SPM/CocoaPods/Manual) when reporting issues

### Reverting to v2.x
If you need to revert:
```swift
// SPM
.package(url: "https://github.com/tolo/HHServices.git", from: "2.1.0")

// CocoaPods
pod 'HHServices', '~> 2.1'
```

## Future Considerations

### v3.1 Roadmap
- [ ] Re-add tvOS support if requested
- [ ] Add macOS support if feasible
- [ ] Consider XCFramework checksum verification
- [ ] Explore GitHub Releases for binary distribution

## Summary

HHServices v3.0 is a drop-in replacement for v2.x with significant build time improvements and better SPM integration. The migration requires only version number updates - no code changes needed.