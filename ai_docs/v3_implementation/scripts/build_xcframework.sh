#!/bin/bash

# HHServices XCFramework Build Script
# Version: 1.0.0
# This script builds HHServices.xcframework for all supported platforms

set -e

# Configuration
FRAMEWORK_NAME="HHServices"
PROJECT_FILE="$FRAMEWORK_NAME.xcodeproj"
SCHEME="$FRAMEWORK_NAME"
BUILD_DIR="build"
OUTPUT_DIR="Binary"
CONFIGURATION="Release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo ""
echo "============================================"
echo "   HHServices XCFramework Build Script"
echo "============================================"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v xcodebuild &> /dev/null; then
    log_error "xcodebuild not found. Please install Xcode."
    exit 1
fi

if [ ! -f "$PROJECT_FILE/project.pbxproj" ]; then
    log_error "Project file not found: $PROJECT_FILE"
    exit 1
fi

log_success "Prerequisites OK"

# Clean previous builds
log_info "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
mkdir -p "$OUTPUT_DIR"
log_success "Clean complete"

# Function to build archive
build_archive() {
    local platform=$1
    local destination=$2
    local archive=$3
    
    log_info "Building for $platform..."
    
    if xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$destination" \
        -archivePath "$BUILD_DIR/$archive.xcarchive" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        DEFINES_MODULE=YES \
        SWIFT_EMIT_MODULE_INTERFACE=YES \
        IPHONEOS_DEPLOYMENT_TARGET=13.0 \
        TVOS_DEPLOYMENT_TARGET=13.0 \
        SWIFT_VERSION=5.0 \
        ONLY_ACTIVE_ARCH=NO \
        ENABLE_BITCODE=NO \
        > "$BUILD_DIR/$archive.log" 2>&1; then
        
        log_success "Built for $platform"
        return 0
    else
        log_error "Failed to build for $platform. Check $BUILD_DIR/$archive.log"
        return 1
    fi
}

# Build for all platforms
log_info "Starting builds..."
echo ""

FAILED_BUILDS=""

if ! build_archive "iOS Device" "generic/platform=iOS" "ios"; then
    FAILED_BUILDS="$FAILED_BUILDS ios"
fi

if ! build_archive "iOS Simulator" "generic/platform=iOS Simulator" "ios-simulator"; then
    FAILED_BUILDS="$FAILED_BUILDS ios-simulator"
fi

if ! build_archive "tvOS Device" "generic/platform=tvOS" "tvos"; then
    FAILED_BUILDS="$FAILED_BUILDS tvos"
fi

if ! build_archive "tvOS Simulator" "generic/platform=tvOS Simulator" "tvos-simulator"; then
    FAILED_BUILDS="$FAILED_BUILDS tvos-simulator"
fi

if [ -n "$FAILED_BUILDS" ]; then
    log_error "Some builds failed: $FAILED_BUILDS"
    exit 1
fi

echo ""
log_info "Creating XCFramework..."

# Build XCFramework command
XCFRAMEWORK_CMD="xcodebuild -create-xcframework"

# Add each framework that exists
for archive in ios ios-simulator tvos tvos-simulator; do
    FRAMEWORK_PATH="$BUILD_DIR/$archive.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
    if [ -d "$FRAMEWORK_PATH" ]; then
        XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $FRAMEWORK_PATH"
    else
        log_warning "Framework not found: $FRAMEWORK_PATH"
    fi
done

XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -output $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

# Create XCFramework
if eval $XCFRAMEWORK_CMD > "$BUILD_DIR/xcframework.log" 2>&1; then
    log_success "XCFramework created successfully"
else
    log_error "Failed to create XCFramework. Check $BUILD_DIR/xcframework.log"
    exit 1
fi

# Verify XCFramework
echo ""
log_info "Verifying XCFramework..."

# Check structure
if [ ! -f "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework/Info.plist" ]; then
    log_error "XCFramework Info.plist not found"
    exit 1
fi

# Check for Swift module
SWIFT_COUNT=$(find "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" -name "*.swiftinterface" | wc -l)
if [ $SWIFT_COUNT -gt 0 ]; then
    log_success "Swift module interface found ($SWIFT_COUNT files)"
else
    log_warning "No Swift module interface found"
fi

# Check for headers
HEADER_COUNT=$(find "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" -name "*.h" | wc -l)
if [ $HEADER_COUNT -gt 0 ]; then
    log_success "Headers found ($HEADER_COUNT files)"
else
    log_error "No headers found"
    exit 1
fi

# Display size information
echo ""
log_info "Size Information:"
SIZE=$(du -sh "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" | cut -f1)
echo "  Total size: $SIZE"

# Display architectures
echo ""
log_info "Architectures:"
for dir in "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"/*; do
    if [ -d "$dir" ] && [[ $(basename "$dir") != "Info.plist" ]]; then
        PLATFORM=$(basename "$dir")
        BINARY="$dir/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
        if [ -f "$BINARY" ]; then
            ARCHS=$(lipo -info "$BINARY" 2>/dev/null | cut -d: -f3)
            echo "  $PLATFORM:$ARCHS"
        fi
    fi
done

# Create ZIP for distribution
echo ""
log_info "Creating distribution ZIP..."
cd "$OUTPUT_DIR"
zip -rq "$FRAMEWORK_NAME.xcframework.zip" "$FRAMEWORK_NAME.xcframework"
cd - > /dev/null

if [ -f "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework.zip" ]; then
    ZIP_SIZE=$(du -sh "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework.zip" | cut -f1)
    log_success "Created $FRAMEWORK_NAME.xcframework.zip ($ZIP_SIZE)"
fi

# Final summary
echo ""
echo "============================================"
echo -e "${GREEN}   BUILD SUCCESSFUL${NC}"
echo "============================================"
echo ""
echo "📦 Output: $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
echo "📦 ZIP: $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework.zip"
echo ""
echo "To use in your Package.swift:"
echo ""
echo "  targets: ["
echo "    .binaryTarget("
echo "      name: \"$FRAMEWORK_NAME\","
echo "      path: \"$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework\""
echo "    )"
echo "  ]"
echo ""
echo "Next steps:"
echo "1. Test the framework in a sample project"
echo "2. Update Package.swift"
echo "3. Commit and tag for release"
echo ""