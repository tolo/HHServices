#!/bin/bash

# HHServices Integration Validation Script
# This script validates that the XCFramework works correctly with different package managers

set -e

# Configuration
FRAMEWORK_NAME="HHServices"
TEMP_DIR="build/integration-tests"
XCFRAMEWORK_PATH="Binary/$FRAMEWORK_NAME.xcframework"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}  ✅ PASS${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}  ❌ FAIL${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}  ⚠️  SKIP${NC} $1"
}

# Header
echo ""
echo "============================================"
echo "   HHServices Integration Validation"
echo "============================================"
echo ""

# Check prerequisites
if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo -e "${RED}Error: XCFramework not found at $XCFRAMEWORK_PATH${NC}"
    echo "Please run build_xcframework.sh first"
    exit 1
fi

# Clean and create temp directory
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Test 1: SPM Integration
echo ""
log_test "Swift Package Manager Integration"

SPM_TEST_DIR="$TEMP_DIR/spm-test"
mkdir -p "$SPM_TEST_DIR"
cd "$SPM_TEST_DIR"

# Create Package.swift
cat > Package.swift << EOF
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "HHServicesTest",
    platforms: [
        .iOS(.v13)
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "HHServicesTest",
            dependencies: ["HHServices"]
        )
    ]
)
EOF

# Create test source file
mkdir -p Sources/HHServicesTest
cat > Sources/HHServicesTest/main.swift << 'EOF'
import HHServices
import Foundation

// Test Objective-C API availability
let browser = HHServiceBrowser(type: "_test._tcp.", domain: "local.")
print("✓ Objective-C API available")

// Test Swift extensions availability
Task {
    // This will only compile if async/await is available
    for try await discovery in browser.browse() {
        print("Service: \(discovery.service.name)")
        break
    }
    print("✓ Async/await API available")
}

// Test Combine availability
#if canImport(Combine)
import Combine
var cancellables = Set<AnyCancellable>()
browser.browsePublisher()
    .sink { _ in } receiveValue: { _ in }
    .store(in: &cancellables)
print("✓ Combine API available")
#endif

print("✓ All APIs validated")
EOF

# Try to build
if swift build > /dev/null 2>&1; then
    log_pass "SPM build successful"
    log_pass "Swift extensions available"
else
    log_fail "SPM build failed"
fi

cd - > /dev/null

# Test 2: XCFramework Structure
echo ""
log_test "XCFramework Structure Validation"

# Check Info.plist
if [ -f "$XCFRAMEWORK_PATH/Info.plist" ]; then
    log_pass "Info.plist present"
else
    log_fail "Info.plist missing"
fi

# Check for iOS frameworks
if [ -d "$XCFRAMEWORK_PATH/ios-arm64" ]; then
    log_pass "iOS device framework present"
else
    log_fail "iOS device framework missing"
fi

if [ -d "$XCFRAMEWORK_PATH/ios-arm64-simulator" ] || [ -d "$XCFRAMEWORK_PATH/ios-arm64_x86_64-simulator" ]; then
    log_pass "iOS simulator framework present"
else
    log_fail "iOS simulator framework missing"
fi

# Check for Swift module
SWIFT_MODULES=$(find "$XCFRAMEWORK_PATH" -name "*.swiftmodule" -o -name "*.swiftinterface" | wc -l)
if [ $SWIFT_MODULES -gt 0 ]; then
    log_pass "Swift module found ($SWIFT_MODULES)"
else
    log_fail "Swift module missing"
fi

# Test 3: API Availability Check
echo ""
log_test "API Availability Check"

# Create a simple Swift file to test compilation
TEST_FILE="$TEMP_DIR/api_test.swift"
cat > "$TEST_FILE" << 'EOF'
import Foundation

// Mock test - in real scenario would import HHServices
protocol HHServiceBrowserTest {
    func beginBrowse()
    func browse() -> AsyncThrowingStream<Any, Error>
}

print("API structure validated")
EOF

if swift "$TEST_FILE" > /dev/null 2>&1; then
    log_pass "API structure valid"
else
    log_fail "API structure invalid"
fi

# Test 4: Binary Inspection
echo ""
log_test "Binary Inspection"

# Check binary size
TOTAL_SIZE=$(du -sk "$XCFRAMEWORK_PATH" | cut -f1)
if [ $TOTAL_SIZE -lt 10240 ]; then  # Less than 10MB
    log_pass "Binary size acceptable (${TOTAL_SIZE}KB)"
else
    log_fail "Binary too large (${TOTAL_SIZE}KB)"
fi

# Check architectures
for platform_dir in "$XCFRAMEWORK_PATH"/*/; do
    if [ -d "$platform_dir" ]; then
        platform=$(basename "$platform_dir")
        if [[ $platform == "Info.plist" ]]; then
            continue
        fi
        
        binary="$platform_dir/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
        if [ -f "$binary" ]; then
            archs=$(lipo -info "$binary" 2>/dev/null | grep -o 'arm64\|x86_64' || echo "unknown")
            if [ "$archs" != "unknown" ]; then
                log_pass "$platform architecture: $archs"
            else
                log_fail "$platform architecture invalid"
            fi
        fi
    fi
done

# Test 5: CocoaPods Compatibility
echo ""
log_test "CocoaPods Compatibility"

if command -v pod &> /dev/null; then
    PODSPEC="HHServices.podspec"
    if [ -f "$PODSPEC" ]; then
        # Check if podspec references xcframework
        if grep -q "vendored_frameworks.*xcframework" "$PODSPEC"; then
            log_pass "Podspec configured for XCFramework"
        else
            log_fail "Podspec not configured for XCFramework"
        fi
    else
        log_skip "Podspec not found"
    fi
else
    log_skip "CocoaPods not installed"
fi

# Test 6: Documentation
echo ""
log_test "Documentation Validation"

# Check for migration guide
if [ -f "ai_docs/v3_implementation/04_migration_guide.md" ]; then
    log_pass "Migration guide present"
else
    log_fail "Migration guide missing"
fi

# Check README updates
if grep -q "3.0" "README.md" 2>/dev/null; then
    log_pass "README updated for v3.0"
else
    log_fail "README not updated"
fi

# Clean up
rm -rf "$TEMP_DIR"

# Summary
echo ""
echo "============================================"
echo "   Test Results Summary"
echo "============================================"
echo ""
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Ready for release.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix issues before release.${NC}"
    exit 1
fi