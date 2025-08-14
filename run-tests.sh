#!/bin/bash

# HHServices Test Runner
echo "🧪 Running HHServices Tests..."
echo "================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build the framework first
echo -e "${YELLOW}Building HHServices framework...${NC}"
if xcodebuild -project HHServices.xcodeproj -scheme HHServices -sdk iphonesimulator build > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Framework built successfully${NC}"
else
    echo -e "${RED}❌ Framework build failed${NC}"
    exit 1
fi

# Build the test target
echo -e "${YELLOW}Building test target...${NC}"
if xcodebuild -project HHServices.xcodeproj -target HHServicesTests -sdk iphonesimulator build > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Test target built successfully${NC}"
else
    echo -e "${RED}❌ Test build failed${NC}"
    exit 1
fi

# Run the tests
echo -e "${YELLOW}Running tests...${NC}"
echo ""

# Use the first available booted simulator or boot one
SIMULATOR_ID=$(xcrun simctl list devices | grep "Booted" | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo "No booted simulator found, booting iPhone 16..."
    SIMULATOR_ID=$(xcrun simctl list devices | grep "iPhone 16 " | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/')
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
fi

# Run tests with detailed output
xcodebuild -project HHServices.xcodeproj \
           -scheme HHServicesTests \
           -sdk iphonesimulator \
           -destination "id=$SIMULATOR_ID" \
           test 2>&1 | grep -E "(Test Case.*started|passed|failed|error:|warning:)" | while IFS= read -r line; do
    if [[ $line == *"passed"* ]]; then
        echo -e "${GREEN}✓ $line${NC}"
    elif [[ $line == *"failed"* ]] || [[ $line == *"error:"* ]]; then
        echo -e "${RED}✗ $line${NC}"
    elif [[ $line == *"warning:"* ]]; then
        echo -e "${YELLOW}⚠ $line${NC}"
    else
        echo "$line"
    fi
done

# Check if tests passed
if xcodebuild -project HHServices.xcodeproj -scheme HHServicesTests -sdk iphonesimulator -destination "id=$SIMULATOR_ID" test 2>&1 | grep -q "** TEST SUCCEEDED **"; then
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}================================${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}================================${NC}"
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}================================${NC}"
    echo ""
    echo "Note: The testServicePublishingAndDiscovery test may fail due to"
    echo "network/Bluetooth requirements. This is expected in simulator."
    exit 1
fi