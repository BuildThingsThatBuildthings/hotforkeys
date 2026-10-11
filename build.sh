#!/bin/bash

# Build script for HotForKeys
# Builds a verified ad-hoc development bundle inside a reproducible archive.

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="HotForKeys"
APP_ARCHIVE="$APP_NAME-local.zip"

echo "Building $APP_NAME..."

# Build the executable
swift build -c release "$@"
BUILD_DIR="$(swift build -c release --show-bin-path "$@")"

python3 scripts/package.py package "$BUILD_DIR/$APP_NAME" --output "$APP_ARCHIVE"
echo "Created: $APP_ARCHIVE (ad-hoc local development artifact)"
echo "Extract and verify without launching or installing:"
echo "  python3 scripts/package.py extract $APP_ARCHIVE"
