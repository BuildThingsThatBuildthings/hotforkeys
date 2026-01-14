#!/bin/bash

# Build script for HotForKeys
# Creates a proper macOS app bundle from the Swift package

set -e

APP_NAME="HotForKeys"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "Building $APP_NAME..."

# Build the executable
swift build -c release

echo "Creating app bundle..."

# Create app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "Done! App bundle created at: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install (copy to Applications):"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "Note: You'll need to grant Accessibility permission in:"
echo "  System Preferences > Privacy & Security > Accessibility"
