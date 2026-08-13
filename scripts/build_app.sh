#!/bin/bash
set -euo pipefail

# Assembles the Luna.app bundle from the release binary.
# Intended to run on macOS (GitHub Actions runner or local).

APP_DIR="dist/Luna.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Cleaning previous bundle"
rm -rf "$APP_DIR"

echo "==> Creating bundle structure"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> Copying release binary"
BINARY=".build/release/DesktopPet"
if [ ! -f "$BINARY" ]; then
  echo "ERROR: Release binary not found at $BINARY"
  echo "       Run 'swift build -c release' first."
  exit 1
fi
cp "$BINARY" "$MACOS_DIR/Luna"
chmod +x "$MACOS_DIR/Luna"

echo "==> Copying Info.plist"
cp Resources/Info.plist "$CONTENTS/Info.plist"

echo "==> Copying artwork (if any)"
if [ -d "Resources/Artwork" ]; then
  cp -R Resources/Artwork "$RESOURCES_DIR/Artwork"
fi

echo "==> Stripping extended attributes (quarantine metadata, etc.)"
xattr -cr "$APP_DIR"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Bundle ready at $APP_DIR"

