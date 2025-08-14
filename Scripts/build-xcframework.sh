#!/bin/bash

# HHServices XCFramework Build Script
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
NC='\033[0m' # No Color

echo "🔨 Building $FRAMEWORK_NAME.xcframework..."
echo "================================"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
mkdir -p "$OUTPUT_DIR"

# Function to build archive
build_archive() {
    local platform=$1
    local destination=$2
    local archive_name=$3
    
    echo -e "${YELLOW}Building for $platform...${NC}"
    
    xcodebuild archive \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$destination" \
        -archivePath "$BUILD_DIR/$archive_name.xcarchive" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        DEFINES_MODULE=YES \
        SWIFT_EMIT_MODULE_INTERFACE=YES \
        IPHONEOS_DEPLOYMENT_TARGET=13.0 \
        TVOS_DEPLOYMENT_TARGET=13.0 \
        SWIFT_VERSION=5.0 \
        ONLY_ACTIVE_ARCH=NO \
        2>&1 | grep -E "^\*\*|error:|warning:" || true
    
    if [ ! -d "$BUILD_DIR/$archive_name.xcarchive" ]; then
        echo -e "${RED}❌ Failed to build for $platform${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Built for $platform${NC}"
}

# Build for each platform
build_archive "iOS Device" "generic/platform=iOS" "ios"
build_archive "iOS Simulator" "generic/platform=iOS Simulator" "ios-simulator"

# Skip tvOS builds for now - can be added later if needed
# echo -e "${YELLOW}Attempting tvOS builds (optional)...${NC}"
# set +e  # Don't exit on error for tvOS
# build_archive "tvOS Device" "generic/platform=tvOS" "tvos"
# TVOS_BUILD_RESULT=$?
# build_archive "tvOS Simulator" "generic/platform=tvOS Simulator" "tvos-simulator"
# TVOS_SIM_BUILD_RESULT=$?
# set -e  # Re-enable exit on error
TVOS_BUILD_RESULT=1
TVOS_SIM_BUILD_RESULT=1

# Create XCFramework
echo -e "${YELLOW}Creating XCFramework...${NC}"

# Build framework args based on what succeeded
FRAMEWORK_ARGS=""
FRAMEWORK_ARGS="$FRAMEWORK_ARGS -framework $BUILD_DIR/ios.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
FRAMEWORK_ARGS="$FRAMEWORK_ARGS -framework $BUILD_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"

if [ $TVOS_BUILD_RESULT -eq 0 ] && [ -d "$BUILD_DIR/tvos.xcarchive" ]; then
    FRAMEWORK_ARGS="$FRAMEWORK_ARGS -framework $BUILD_DIR/tvos.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
    echo -e "${GREEN}✅ Including tvOS Device${NC}"
fi

if [ $TVOS_SIM_BUILD_RESULT -eq 0 ] && [ -d "$BUILD_DIR/tvos-simulator.xcarchive" ]; then
    FRAMEWORK_ARGS="$FRAMEWORK_ARGS -framework $BUILD_DIR/tvos-simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
    echo -e "${GREEN}✅ Including tvOS Simulator${NC}"
fi

xcodebuild -create-xcframework $FRAMEWORK_ARGS -output "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

if [ ! -d "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" ]; then
    echo -e "${RED}❌ Failed to create XCFramework${NC}"
    exit 1
fi

# Sign the XCFramework
echo -e "${YELLOW}Signing XCFramework...${NC}"
codesign --sign - --force --deep "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ XCFramework signed${NC}"
else
    echo -e "${YELLOW}⚠️  Failed to sign XCFramework (non-critical)${NC}"
fi

# Verify XCFramework structure
echo -e "${YELLOW}Verifying XCFramework...${NC}"

# Check for Swift module interface
if find "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" -name "*.swiftinterface" | grep -q .; then
    echo -e "${GREEN}✅ Swift module interface found${NC}"
else
    echo -e "${YELLOW}⚠️  No Swift module interface found (might be ObjC only)${NC}"
fi

# Check for headers
if find "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" -name "*.h" | grep -q .; then
    echo -e "${GREEN}✅ Headers found${NC}"
else
    echo -e "${RED}❌ No headers found${NC}"
    exit 1
fi

# Display framework info
echo ""
echo "📦 XCFramework Info:"
echo "-------------------"
ls -lh "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
echo ""
echo "Architectures:"
find "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" -name Info.plist -exec plutil -p {} \; | grep -E "Architecture|Platform" | sort -u

# Calculate size
SIZE=$(du -sh "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" | cut -f1)
echo ""
echo "Total Size: $SIZE"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ XCFramework built successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Location: $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
echo ""
echo "To use in Swift Package Manager, update Package.swift:"
echo "  .binaryTarget("
echo "      name: \"$FRAMEWORK_NAME\","
echo "      path: \"$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework\""
echo "  )"