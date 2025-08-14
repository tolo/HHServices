#!/bin/bash

# Script to run tests using the source-based configuration

set -e

echo "🧪 Running HHServices Tests..."
echo "================================"

# Set environment variable to use source-based targets for testing
export HHSERVICES_DEV=1

# Clean previous test builds
rm -rf .build

# Run tests
swift test

echo ""
echo "✅ All tests passed!"