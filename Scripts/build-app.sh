#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then echo "This app requires macOS and Xcode Command Line Tools."; exit 1; fi
swift build -c release --product FitBOSSApp
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR=".build/FitBOSS.app"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_DIR/FitBOSSApp" "$APP_DIR/Contents/MacOS/FitBOSSApp"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"
echo "Launch: open $APP_DIR"
