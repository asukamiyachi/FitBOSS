#!/bin/bash
# Local drag-and-drop DMG packaging; no GitHub release or deployment.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Requires macOS hdiutil" >&2
  exit 1
fi
APP_PATH=".build/FitBOSS.app"
OUTPUT_DIR=".build/dist"
if [[ ! -d "$APP_PATH" || ! -f "$APP_PATH/Contents/Info.plist" || ! -x "$APP_PATH/Contents/MacOS/FitBOSSApp" ]]; then
  echo "FitBOSS.app is incomplete; run Scripts/build-app.sh first" >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
STAGING="$(mktemp -d -t fitboss-dmg)"
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto "$APP_PATH" "$STAGING/FitBOSS.app"
/bin/ln -s /Applications "$STAGING/Applications"
/usr/bin/hdiutil create -ov -format UDZO -fs HFS+ -volname FitBOSS \
  -srcfolder "$STAGING" "$OUTPUT_DIR/FitBOSS.dmg"
/usr/bin/hdiutil verify "$OUTPUT_DIR/FitBOSS.dmg"
echo "Internal DMG: $OUTPUT_DIR/FitBOSS.dmg"
