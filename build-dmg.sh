#!/bin/bash
# build-dmg.sh — builds HydroBar.app in Release and packages it as a DMG
# Usage: ./build-dmg.sh

set -euo pipefail

VERSION="1.2"
SCHEME="HydroBar"
PROJECT="src/HydroBar/HydroBar.xcodeproj"
BUILD_DIR="/tmp/HydroBar-build"
DMG_NAME="HydroBar-v${VERSION}.dmg"
DMG_BACKGROUND="Resources/DMG-background.png"

echo "→ Cleaning previous build..."
rm -rf "$BUILD_DIR" "$DMG_NAME"

echo "→ Building HydroBar (Release)..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|warning:|Build succeeded|Build FAILED" || true

APP_PATH=$(find "$BUILD_DIR" -name "HydroBar.app" -not -path "*/Index*" | head -1)

if [ -z "$APP_PATH" ]; then
  echo "✗ Build failed — HydroBar.app not found"
  exit 1
fi

echo "→ App built: $APP_PATH"

echo "→ Creating DMG..."
create-dmg \
  --volname "HydroBar" \
  --background "$DMG_BACKGROUND" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "HydroBar.app" 180 185 \
  --hide-extension "HydroBar.app" \
  --app-drop-link 480 185 \
  "$DMG_NAME" \
  "$APP_PATH"

echo ""
echo "✓ Done: $(pwd)/$DMG_NAME"
