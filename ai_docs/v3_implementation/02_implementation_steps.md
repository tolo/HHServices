# Implementation Steps - HHServices v3.0

> **NOTE: ACTUAL IMPLEMENTATION DIFFERED** 
> 
> We implemented v3.0 as a **100% Pure Swift migration** instead of XCFramework distribution.
> This turned out to be a superior solution that eliminated all SPM mixed-language issues.
> 
> See README.md for what was actually delivered.
> 
> The steps below were the original XCFramework plan, kept for reference.

## Phase 1: Project Configuration

### Step 1.1: Update Xcode Project Settings

```bash
# Open project in Xcode
open HHServices.xcodeproj
```

Update Build Settings for HHServices target:
- [ ] Set `BUILD_LIBRARY_FOR_DISTRIBUTION` = `YES`
- [ ] Set `SWIFT_EMIT_MODULE_INTERFACE` = `YES`  
- [ ] Set `DEFINES_MODULE` = `YES`
- [ ] Set `SKIP_INSTALL` = `NO`
- [ ] Set `ONLY_ACTIVE_ARCH` = `NO` (for Release)
- [ ] Verify `IPHONEOS_DEPLOYMENT_TARGET` = `13.0`
- [ ] Verify `TVOS_DEPLOYMENT_TARGET` = `13.0`
- [ ] Verify `SWIFT_VERSION` = `5.0`

### Step 1.2: Ensure Swift File Integration

Verify file locations:
```bash
# Swift file should be in HHServices directory
ls -la HHServices/HHServices+Swift.swift

# Verify it's included in Compile Sources
grep -n "HHServices+Swift.swift" HHServices.xcodeproj/project.pbxproj
```

### Step 1.3: Configure Module Map

Ensure `Supporting Files/module.modulemap` exists:
```modulemap
framework module HHServices {
    umbrella header "HHServices.h"
    
    export *
    module * { export * }
}
```

## Phase 2: Build Automation

### Step 2.1: Create Build Script

Create `Scripts/build_xcframework.sh`:
```bash
#!/bin/bash
set -e

FRAMEWORK_NAME="HHServices"
BUILD_DIR="build"
OUTPUT_DIR="Binary"

# Clean
rm -rf "$BUILD_DIR" "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
mkdir -p "$OUTPUT_DIR"

# Function to build archive
build_archive() {
    local platform=$1
    local destination=$2
    local archive=$3
    
    xcodebuild archive \
        -project "$FRAMEWORK_NAME.xcodeproj" \
        -scheme "$FRAMEWORK_NAME" \
        -configuration Release \
        -destination "$destination" \
        -archivePath "$BUILD_DIR/$archive.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

# Build all platforms
build_archive "iOS" "generic/platform=iOS" "ios"
build_archive "iOS Simulator" "generic/platform=iOS Simulator" "ios-simulator"
build_archive "tvOS" "generic/platform=tvOS" "tvos"
build_archive "tvOS Simulator" "generic/platform=tvOS Simulator" "tvos-simulator"

# Create XCFramework
xcodebuild -create-xcframework \
    -framework "$BUILD_DIR/ios.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -framework "$BUILD_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -framework "$BUILD_DIR/tvos.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -framework "$BUILD_DIR/tvos-simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -output "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

echo "✅ Built $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
```

### Step 2.2: Test Build Process

```bash
# Make script executable
chmod +x Scripts/build_xcframework.sh

# Run build
./Scripts/build_xcframework.sh

# Verify output
ls -la Binary/HHServices.xcframework/
```

### Step 2.3: Verify Framework Contents

```bash
# Check for Swift module
find Binary/HHServices.xcframework -name "*.swiftinterface" -o -name "*.swiftmodule"

# Check for headers
find Binary/HHServices.xcframework -name "*.h"

# Check architectures
lipo -info Binary/HHServices.xcframework/ios-arm64/HHServices.framework/HHServices
```

## Phase 3: Package Configuration

### Step 3.1: Update Package.swift

```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "HHServices",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "HHServices",
            targets: ["HHServices"])
    ],
    targets: [
        .binaryTarget(
            name: "HHServices",
            path: "Binary/HHServices.xcframework"
        )
    ]
)
```

### Step 3.2: Update .gitignore

Add to `.gitignore`:
```
# Build artifacts
build/
DerivedData/

# Keep XCFramework for distribution
!Binary/HHServices.xcframework
```

### Step 3.3: Update CocoaPods Spec

```ruby
Pod::Spec.new do |s|
  s.name         = 'HHServices'
  s.version      = '3.0.0'
  s.summary      = 'iOS Bluetooth P2P DNS-SD with async/await'
  s.homepage     = 'https://github.com/tolo/HHServices'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Tobias Löfstrand' => 'tobias@leafnode.se' }
  s.source       = { :git => 'https://github.com/tolo/HHServices.git', 
                     :tag => s.version.to_s }
  
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  
  s.vendored_frameworks = 'Binary/HHServices.xcframework'
  s.swift_version = '5.0'
end
```

## Phase 4: Testing & Validation

### Step 4.1: Create Test SPM Project

```bash
mkdir TestSPMIntegration
cd TestSPMIntegration
swift package init --type executable

# Edit Package.swift to add HHServices dependency
```

Test Package.swift:
```swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TestSPMIntegration",
    platforms: [.iOS(.v13)],
    dependencies: [
        .package(path: "../HHServices")
    ],
    targets: [
        .target(
            name: "TestSPMIntegration",
            dependencies: ["HHServices"])
    ]
)
```

### Step 4.2: Verify API Availability

Create test file:
```swift
import HHServices

func testAsyncAwait() async throws {
    let browser = HHServiceBrowser(type: "_test._tcp.", domain: "local.")
    
    // This should compile - proving async/await is available
    for try await discovery in browser.browse() {
        print("Found: \(discovery.service.name)")
    }
}

func testCombine() {
    let browser = HHServiceBrowser(type: "_test._tcp.", domain: "local.")
    
    // This should compile - proving Combine is available
    _ = browser.browsePublisher()
        .sink { _ in } receiveValue: { discovery in
            print("Found: \(discovery.service.name)")
        }
}
```

### Step 4.3: Device Testing

1. Build test app for device
2. Deploy to 2+ iOS devices
3. Test Bluetooth P2P discovery
4. Verify no regressions

## Phase 5: CI/CD Setup

### Step 5.1: GitHub Actions Workflow

Create `.github/workflows/build-release.yml`:
```yaml
name: Build Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-xcframework:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      
      - name: Build XCFramework
        run: ./Scripts/build_xcframework.sh
      
      - name: Upload XCFramework
        uses: actions/upload-artifact@v3
        with:
          name: HHServices.xcframework
          path: Binary/HHServices.xcframework
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: Binary/HHServices.xcframework.zip
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Step 5.2: Validation Script

Create `Scripts/validate_release.sh`:
```bash
#!/bin/bash

echo "Validating release..."

# Check XCFramework exists
if [ ! -d "Binary/HHServices.xcframework" ]; then
    echo "❌ XCFramework not found"
    exit 1
fi

# Check Package.swift valid
swift package dump-package > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Package.swift invalid"
    exit 1
fi

# Check CocoaPods spec
pod spec lint HHServices.podspec --allow-warnings
if [ $? -ne 0 ]; then
    echo "❌ Podspec validation failed"
    exit 1
fi

echo "✅ Release validation passed"
```

## Phase 6: Documentation

### Step 6.1: Update README.md

Add installation section:
```markdown
## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/tolo/HHServices.git", from: "3.0.0")
]
```

### CocoaPods

```ruby
pod 'HHServices', '~> 3.0'
```

### What's New in v3.0

- 🎉 Full async/await support via SPM
- 🎉 Single import for all features
- 🎉 Combine publishers included
- ✅ 100% backward compatible
```

### Step 6.2: Create Migration Guide

See `04_migration_guide.md` for template.

### Step 6.3: Update Sample Projects

Update all sample projects to use v3.0 and demonstrate new features.

## Phase 7: Release

### Step 7.1: Final Checklist

- [ ] All tests passing
- [ ] XCFramework builds on CI
- [ ] Documentation updated
- [ ] Migration guide ready
- [ ] CHANGELOG updated
- [ ] Version bumped to 3.0.0

### Step 7.2: Create Release

```bash
# Commit all changes
git add .
git commit -m "Release v3.0.0 - XCFramework distribution with full SPM support"

# Tag release
git tag -a v3.0.0 -m "Version 3.0.0"

# Push
git push origin main
git push origin v3.0.0
```

### Step 7.3: Publish to CocoaPods

```bash
# Validate podspec
pod spec lint HHServices.podspec

# Push to trunk
pod trunk push HHServices.podspec
```

### Step 7.4: Announce Release

1. Create GitHub Release with notes
2. Post to relevant forums/channels
3. Update any documentation sites

## Troubleshooting

### Build Failures

If XCFramework build fails:
1. Check Xcode version (14.0+ required)
2. Verify build settings
3. Clean derived data
4. Check for compilation errors

### SPM Integration Issues

If SPM can't find module:
1. Verify Package.swift syntax
2. Check binary target path
3. Clear SPM cache: `rm -rf ~/Library/Caches/org.swift.swiftpm`
4. Try explicit version instead of branch

### Binary Size Concerns

To reduce size:
1. Enable bitcode stripping
2. Remove debug symbols for Release
3. Use optimization level -Os
4. Consider per-platform distribution

## Issue Resolution

If critical issues found:

1. **Immediate**: Add warning to README
2. **Next**: Prepare 3.0.1 hotfix
3. **Then**: Release fix
4. **Communicate**: Clear explanation to users

## Success Confirmation

Version 3.0 is successful when:
- [ ] SPM users can use async/await
- [ ] Single import works everywhere
- [ ] No breaking changes reported
- [ ] Download/integration time acceptable
- [ ] Positive user feedback received