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
# The current distribution is deliberately an offline-only beta.
# Refuse to package a previously built Firebase-enabled app or development
# provisioning profile. A signed online release needs its own reviewed flow.
if [[ -e "$APP_PATH/Contents/Resources/GoogleService-Info.plist" ||
      -e "$APP_PATH/Contents/embedded.provisionprofile" ]]; then
  echo "Refusing DMG with Firebase config or development profile; rebuild offline." >&2
  exit 1
fi
/usr/bin/python3 - "$APP_PATH/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as source: info=plistlib.load(source)
if info.get("FitBOSSBuildMode") != "offline":
    raise SystemExit("Refusing DMG: only an explicitly offline FitBOSS build can be packaged")
if info.get("CFBundleURLTypes"):
    raise SystemExit("Refusing DMG with OAuth URL schemes; rebuild offline")
PY
mkdir -p "$OUTPUT_DIR"
STAGING="$(mktemp -d -t fitboss-dmg)"
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto "$APP_PATH" "$STAGING/FitBOSS.app"
/bin/ln -s /Applications "$STAGING/Applications"
/usr/bin/hdiutil create -ov -format UDZO -fs HFS+ -volname FitBOSS \
  -srcfolder "$STAGING" "$OUTPUT_DIR/FitBOSS.dmg"
/usr/bin/hdiutil verify "$OUTPUT_DIR/FitBOSS.dmg"
echo "Internal DMG: $OUTPUT_DIR/FitBOSS.dmg"
