#!/bin/bash
set -euo pipefail

# Creates Luna.dmg from the assembled .app bundle.
# Usage: bash scripts/make_dmg.sh

APP="dist/Luna.app"
DMG="dist/Luna.dmg"

if [ ! -d "$APP" ]; then
  echo "ERROR: $APP not found. Run scripts/build_app.sh first."
  exit 1
fi

echo "==> Removing old DMG if present"
rm -f "$DMG"

echo "==> Creating DMG"
hdiutil create \
  -volname "Luna" \
  -srcfolder "$APP" \
  -ov \
  -format UDZO \
  "$DMG"

echo "==> DMG created at $DMG"
