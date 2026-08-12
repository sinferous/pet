#!/bin/bash
set -euo pipefail

# Creates Luna.dmg from the assembled .app bundle.
# Usage: bash scripts/make_dmg.sh

APP="dist/Luna.app"
DMG="dist/Luna.dmg"

STAGE="dist/dmg_stage"

if [ ! -d "$APP" ]; then
  echo "ERROR: $APP not found. Run scripts/build_app.sh first."
  exit 1
fi

echo "==> Removing old DMG and staging folder if present"
rm -f "$DMG"
rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "==> Copying app to staging area"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating DMG"
hdiutil create \
  -volname "Luna" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "==> Cleaning up staging area"
rm -rf "$STAGE"

echo "==> DMG created at $DMG"
