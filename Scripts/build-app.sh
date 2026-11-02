#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then echo "This app requires macOS and Xcode Command Line Tools."; exit 1; fi
swift build -c release --product FitBOSSApp
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR=".build/FitBOSS.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/FitBOSSApp" "$APP_DIR/Contents/MacOS/FitBOSSApp"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
if [[ "${FITBOSS_FIREBASE_ENABLED:-0}" == "1" ]]; then
    CONFIG="LocalConfig/GoogleService-Info.plist"
    if [[ ! -f "$CONFIG" ]]; then
        echo "Missing $CONFIG; re-download it after Google Sign-In is enabled." >&2
        exit 1
    fi
    cp "$CONFIG" "$APP_DIR/Contents/Resources/GoogleService-Info.plist"
    /usr/bin/python3 - "$APP_DIR/Contents/Info.plist" "$CONFIG" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as file: info = plistlib.load(file)
with open(sys.argv[2], "rb") as file: conf = plistlib.load(file)
if conf.get("PROJECT_ID") != "fitboss-acde2":
    raise SystemExit("Firebase PROJECT_ID must be fitboss-acde2")
if conf.get("BUNDLE_ID") != "com.asukamiyachi.FitBOSS":
    raise SystemExit("Firebase BUNDLE_ID must match FitBOSS")
if not conf.get("CLIENT_ID") or not conf.get("DATABASE_URL"):
    raise SystemExit("Missing CLIENT_ID or DATABASE_URL; download updated plist")
reverse = conf.get("REVERSED_CLIENT_ID")
if not reverse: raise SystemExit("Missing REVERSED_CLIENT_ID; download updated plist")
info["CFBundleURLTypes"] = [{"CFBundleURLSchemes": [reverse]}]
with open(sys.argv[1], "wb") as file: plistlib.dump(info, file)
PY
fi
# Local test build only: Google Keychain flows require proper Apple Development signing.
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"
echo "Launch: open $APP_DIR"
