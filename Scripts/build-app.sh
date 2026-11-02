#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then echo "This app requires macOS and Xcode Command Line Tools."; exit 1; fi
SIGNING_IDENTITY="${FITBOSS_SIGNING_IDENTITY:--}"
PROFILE="${FITBOSS_PROVISIONING_PROFILE:-}"
if [[ "${FITBOSS_FIREBASE_ENABLED:-0}" == "1" && "$SIGNING_IDENTITY" != "-" && ! -f "$PROFILE" ]]; then
    echo "A matching macOS profile is required: set FITBOSS_PROVISIONING_PROFILE before real Google login testing." >&2
    exit 1
fi
BUILD_DIR="${FITBOSS_BUILD_DIR:-.build}"
CONFIGURATION="${FITBOSS_BUILD_CONFIGURATION:-release}"
BUILD_ARGS=(--scratch-path "$BUILD_DIR" -c "$CONFIGURATION")
swift build "${BUILD_ARGS[@]}" --product FitBOSSApp
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
# Build into a fresh .app so Firebase settings, provisioning profiles, and
# SPM bundles cannot remain after switching back to the offline build.
APP_DIR="$BUILD_DIR/FitBOSS.app"
mkdir -p "$BUILD_DIR"
STAGING_DIR="$(mktemp -d "$BUILD_DIR/.FitBOSS-build.XXXXXXXX")"
BUILD_APP="$STAGING_DIR/FitBOSS.app"
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$BUILD_APP/Contents/MacOS" "$BUILD_APP/Contents/Resources"
cp "$BIN_DIR/FitBOSSApp" "$BUILD_APP/Contents/MacOS/FitBOSSApp"
cp Resources/Info.plist "$BUILD_APP/Contents/Info.plist"
# A signed bundle carries its build flavor so the offline DMG can fail closed
# even when a developer manually removes the online Firebase plist.
# Metadata is written before codesigning and is not sensitive configuration.
/usr/bin/python3 - "$BUILD_APP/Contents/Info.plist" "${FITBOSS_FIREBASE_ENABLED:-0}" <<'PYMODE'
import plistlib, sys
with open(sys.argv[1], "rb") as source:
    info = plistlib.load(source)
info["FitBOSSBuildMode"] = "firebase" if sys.argv[2] == "1" else "offline"
with open(sys.argv[1], "wb") as target:
    plistlib.dump(info, target)
PYMODE
# Old SwiftPM binary folders may retain SDK bundles across build-mode switches.
# Only the opt-in Firebase build needs third-party SDK resource bundles.
if [[ "${FITBOSS_FIREBASE_ENABLED:-0}" == "1" ]]; then
    for bundle in "$BIN_DIR"/*.bundle; do
        [[ -d "$bundle" ]] || continue
        ditto "$bundle" "$BUILD_APP/Contents/Resources/$(basename "$bundle")"
    done
    CONFIG="LocalConfig/GoogleService-Info.plist"
    if [[ ! -f "$CONFIG" ]]; then
        echo "Missing $CONFIG; re-download it after Google Sign-In is enabled." >&2
        exit 1
    fi
    cp "$CONFIG" "$BUILD_APP/Contents/Resources/GoogleService-Info.plist"
    /usr/bin/python3 - "$BUILD_APP/Contents/Info.plist" "$CONFIG" <<'PY'
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
# Supply an existing Apple Development identity for real Google/Keychain testing.
# The default remains ad-hoc for offline CI, without exporting private keys.
codesign --force --sign "$SIGNING_IDENTITY" "$BUILD_APP"
if [[ "${FITBOSS_FIREBASE_ENABLED:-0}" == "1" && "$SIGNING_IDENTITY" != "-" ]]; then
    TEAM_ID="$(codesign -dv "$BUILD_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    ENTITLEMENTS="$BUILD_DIR/FitBOSS.entitlements"
    /usr/bin/python3 - "$TEAM_ID" "$ENTITLEMENTS" "$PROFILE" <<'PYENT'
import datetime, fnmatch, plistlib, re, subprocess, sys
team = sys.argv[1]
if not re.fullmatch(r"[A-Z0-9]{10}", team):
    raise SystemExit("Cannot determine Apple Development signing team")
app_id = team + ".com.asukamiyachi.FitBOSS"
profile = plistlib.loads(subprocess.run(["security", "cms", "-D", "-i", sys.argv[3]], capture_output=True, check=True).stdout)
allowed = profile.get("Entitlements", {})
if "OSX" not in profile.get("Platform", []) or team not in profile.get("TeamIdentifier", []):
    raise SystemExit("Profile platform or signing team does not match")
if not fnmatch.fnmatchcase(app_id, allowed.get("com.apple.application-identifier", "")):
    raise SystemExit("Profile does not authorize the FitBOSS bundle ID")
if not any(fnmatch.fnmatchcase(app_id, group) for group in allowed.get("keychain-access-groups", [])):
    raise SystemExit("Profile does not authorize the FitBOSS Keychain group")
if profile.get("ExpirationDate", datetime.datetime.min) <= datetime.datetime.utcnow():
    raise SystemExit("Provisioning profile expired")
with open(sys.argv[2], "wb") as file:
    plistlib.dump({"com.apple.application-identifier": app_id,
                  "keychain-access-groups": [app_id]}, file)
PYENT
    cp "$PROFILE" "$BUILD_APP/Contents/embedded.provisionprofile"
    codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$BUILD_APP"
fi
codesign --verify --deep --strict "$BUILD_APP"
if [[ -L "$APP_DIR" || ( -e "$APP_DIR" && ! -d "$APP_DIR" ) ]]; then
    echo "Refusing to replace a symlink or a non-directory app path: $APP_DIR" >&2
    exit 1
fi
rm -rf "$APP_DIR"
mv "$BUILD_APP" "$APP_DIR"
rmdir "$STAGING_DIR"
trap - EXIT
echo "Built $APP_DIR"
echo "Launch: open $APP_DIR"
