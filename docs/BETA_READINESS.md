# FitBOSS beta readiness (development gate)

**Scope:** GitHub PR #6 is a pre-release preparation change. It does not publish a beta, deploy Firebase, change billing, create a public Release or merge anything to main.

## Functional and build-mode matrix

| Area | What the code supports | Status / required evidence |
| --- | --- | --- |
| Camera and pose counter | macOS AVFoundation / Vision; 2D experimental push-up evaluation; frames and landmarks stay on-device | Existing Swift/Core tests and macOS builds; **hardware camera, camera permissions, foreground/background switching remain untested in PR #6** |
| Workout history and rest days | Atomic Application Support JSON persistence, legacy UserDefaults migration, JST grouping and rest-aware streak; shared across windows | Existing Core and window tests run in macOS CI; **real user data migration and manual UI tests not repeated in PR #6** |
| Default macOS app | No Firebase SDK dependency, no login or backend requirements; local training remains available | `swift test`, `bash Scripts/build-app.sh`; internal DMG builds this **offline** target only |
| Optional online app | `FITBOSS_FIREBASE_ENABLED=1`, official Firebase/Google SDK, local plist and appropriate Apple signing/profile for actual Google login | CI verifies SDK compilation only; Google login/RTDB connection were verified previously, not repeated here. Team/room Functions not deployed |
| DMG internals | `FitBOSS.app` plus `Applications -> /Applications` shortcut | macOS CI builds/opens internal DMG and checks app code signature; tests stale Firebase config rejection and removal |
| Public macOS distribution | Developer ID signing, Apple notarization, stapling, real Gatekeeper acceptance | **NOT DONE**. No Developer ID credentials or public GitHub Release are asserted; README Coming soon badge remains non-clickable |
| Firebase backend | Authenticated callables, Rules and room logic available in source | **No new Emulator tests in PR #6.** Cloud Functions still not deployed; no claims of production readiness |

## Fixed in PR #6

1. **P2 / stale OAuth data in offline app output:** `Scripts/build-app.sh` now constructs a fresh staged `FitBOSS.app` on every build. Signing is verified before replacing the previous completed bundle. Prior `GoogleService-Info.plist`, OAuth URL schemes, development `embedded.provisionprofile`, or SwiftPM cached SDK bundles cannot survive an offline rebuild. Non-Firebase builds never copy third-party SPM resource bundles from the reused binary cache.
2. **P2 / accidental offline DMG contamination:** `Scripts/create-dmg.sh` refuses to package an app containing Firebase config, a development provisioning profile, OAuth URL schemes, or a build manifest other than `FitBOSSBuildMode=offline`. This rejects stripped-down online binaries even if no plist remains. This pipeline is intentionally offline-only. A genuine signed Firebase-enabled public distribution needs a separately reviewed release flow.
3. **CI regression:** inject synthetic (non-secret) Firebase settings, an OAuth URL scheme, an online-mode marker and a cached SDK bundle into the offline build, verify DMG packaging rejects it, rebuild offline, and verify the app and mounted DMG no longer contain stale data.
4. **CI scope control:** the Firebase Emulator integration job is only required for PR changes to `functions/`, `firebase/`, `firebase.json` or `.firebaserc`. For app/DMG-only PRs, it skips automatically; normal macOS tests, JS syntax/domain tests and Firebase-SDK compilation still run.

## Test commands (on macOS, without Emulator)

```bash
swift test
bash Scripts/build-app.sh
bash Scripts/create-dmg.sh
hdiutil verify .build/dist/FitBOSS.dmg
FITBOSS_FIREBASE_ENABLED=1 swift build -c debug --product FitBOSSApp
```

**Never commit** `LocalConfig/GoogleService-Info.plist`, Apple certificates/profiles, private keys, Firebase tokens or personal workout records.

## Manual acceptance tests deferred

- macOS 14+ and Apple Silicon: camera selection, access grant/refusal, start/stop on navigation, skeleton/counter quality.
- Save, reload, edit/delete history and rest days, including two-window operation and migration from a real prior installation.
- Firebase-enabled signed build: Google sign-in, OAuth callback, Keychain restore and multi-device presence; security must be evaluated again before deployment.
- Internal DMG: mount in Finder, drag to Applications, relaunch and camera permissions.
- Public distribution: properly configure Apple Developer ID and notary credentials, ensure a notarized and stapled application is Gatekeeper accepted, then separately authorize a Release. README must not link to a nonexistent asset.

## Remaining known limitations (not blockers for **offline internal beta infrastructure**)

- Cloud Functions remain undeployed; real team joins, online match/ranking and server-derived last-offline timestamps do not function end-to-end in a public installation.
- App Check, data deletion and retention, cloud costs and server operation need product/security review.
- User approval is required before Firebase production deploy, billing changes, Apple release credential setup or publication. No such actions are part of PR #6.
- Test coverage cannot replace live device/UX, paid signing and notarization validation.
