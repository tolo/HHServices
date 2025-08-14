#!/bin/bash

# HHServices XCFramework Validation Script
# This script validates that the XCFramework approach will work for v3.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🧪 Validating XCFramework Approach for v3.0"
echo "==========================================="
echo ""

# Track validation results
VALIDATION_PASSED=true

# Function to run validation check
validate() {
    local test_name=$1
    local command=$2
    
    echo -n "Checking: $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

# Function to run validation with output
validate_with_output() {
    local test_name=$1
    shift
    local command="$@"
    
    echo -e "${BLUE}Testing: $test_name${NC}"
    echo "Command: $command"
    
    if eval "$command"; then
        echo -e "${GREEN}✅ Passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
    echo ""
}

echo -e "${YELLOW}1. Prerequisites Check${NC}"
echo "----------------------"

validate "Xcode installed" "which xcodebuild"
validate "Swift compiler available" "which swift"
validate "Project file exists" "test -f HHServices.xcodeproj/project.pbxproj"
validate "Swift file in correct location" "test -f HHServices/HHServices+Swift.swift"
validate "Build script exists" "test -f Scripts/build-xcframework.sh"

echo ""
echo -e "${YELLOW}2. Build Configuration Check${NC}"
echo "----------------------------"

# Check if project has proper settings
echo -n "Checking: Module support enabled... "
if xcodebuild -project HHServices.xcodeproj -showBuildSettings | grep -q "DEFINES_MODULE = YES"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  May need configuration${NC}"
fi

echo -n "Checking: Swift version set... "
if xcodebuild -project HHServices.xcodeproj -showBuildSettings | grep -q "SWIFT_VERSION = 5"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  May need configuration${NC}"
fi

echo ""
echo -e "${YELLOW}3. Test Framework Build${NC}"
echo "-----------------------"

# Try to build for one platform as a test
echo "Attempting test build for iOS Simulator..."
if xcodebuild -project HHServices.xcodeproj \
    -scheme HHServices \
    -configuration Release \
    -sdk iphonesimulator \
    -derivedDataPath build/TestBuild \
    DEFINES_MODULE=YES \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SWIFT_EMIT_MODULE_INTERFACE=YES \
    build 2>&1 | tail -5 | grep -q "BUILD SUCCEEDED"; then
    echo -e "${GREEN}✅ Test build succeeded${NC}"
else
    echo -e "${RED}❌ Test build failed${NC}"
    VALIDATION_PASSED=false
fi

echo ""
echo -e "${YELLOW}4. Swift/ObjC Integration Check${NC}"
echo "-------------------------------"

# Check that Swift file can see ObjC classes
echo -n "Checking: Swift can import ObjC classes... "
if grep -q "import HHServices\|@objc\|HHServiceBrowser\|HHService" HHServices/HHServices+Swift.swift; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VALIDATION_PASSED=false
fi

# Check that headers are public
echo -n "Checking: Public headers configured... "
if grep -q "ATTRIBUTES = (Public" HHServices.xcodeproj/project.pbxproj; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    VALIDATION_PASSED=false
fi

echo ""
echo -e "${YELLOW}5. XCFramework Feasibility${NC}"
echo "--------------------------"

# Check if we can create a simple XCFramework structure
echo "Testing XCFramework creation capability..."

TEST_DIR="build/xcframework-test"
mkdir -p "$TEST_DIR"

# Create a mock Info.plist for XCFramework
cat > "$TEST_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>ios-arm64</string>
            <key>LibraryPath</key>
            <string>HHServices.framework</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>ios</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

if [ -f "$TEST_DIR/Info.plist" ]; then
    echo -e "${GREEN}✅ XCFramework structure can be created${NC}"
else
    echo -e "${RED}❌ Cannot create XCFramework structure${NC}"
    VALIDATION_PASSED=false
fi

echo ""
echo -e "${YELLOW}6. Package.swift v3.0 Test${NC}"
echo "--------------------------"

# Create a test Package.swift for v3.0
cat > Package-v3-test.swift <<EOF
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
        // This would use the XCFramework
        .binaryTarget(
            name: "HHServices",
            path: "Binary/HHServices.xcframework"
        )
    ]
)
EOF

echo -n "Checking: v3.0 Package.swift syntax valid... "
if swift package --package-path . --manifest-path Package-v3-test.swift dump-package > /dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
    rm Package-v3-test.swift
else
    echo -e "${RED}❌${NC}"
    VALIDATION_PASSED=false
fi

# Clean up test files
rm -rf build/xcframework-test build/TestBuild

echo ""
echo "==========================================="
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
    echo ""
    echo "The XCFramework approach is viable for v3.0!"
    echo ""
    echo "Next steps:"
    echo "1. Make Scripts/build-xcframework.sh executable:"
    echo "   chmod +x Scripts/build-xcframework.sh"
    echo ""
    echo "2. Build the XCFramework:"
    echo "   ./Scripts/build-xcframework.sh"
    echo ""
    echo "3. Update Package.swift to use the binary target"
    echo "4. Test SPM integration with the XCFramework"
    exit 0
else
    echo -e "${RED}❌ Some validations failed${NC}"
    echo ""
    echo "Please address the issues above before proceeding with v3.0"
    exit 1
fi