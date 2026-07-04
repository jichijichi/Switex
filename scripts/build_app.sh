#!/bin/bash
# Build the switex macOS menu bar app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/switex"
BUILD_DIR="$APP_DIR/.build"

echo "=== Building switex macOS App ==="

cd "$APP_DIR"

# Check for Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found. Install Xcode or Command Line Tools."
    exit 1
fi

echo "Building with Swift Package Manager..."

swift build -c release --arch arm64 2>&1 || swift build -c release 2>&1

if [ -f "$BUILD_DIR/release/switex" ]; then
    echo ""
    echo "Build successful!"
    echo "Binary: $BUILD_DIR/release/switex"
    echo ""
    echo "To run:  $BUILD_DIR/release/switex"
else
    echo ""
    echo "Build completed but binary not found at expected path."
    echo "Check $BUILD_DIR for output."
fi
