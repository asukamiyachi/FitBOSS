# FitBOSS (macOS prototype)

macOS native SwiftUI / AVFoundation / Apple Vision experimental exercise tracker.

**Current phase:** native SwiftUI prototype with on-device camera/pose tracking, atomic local workout history, and optional Firebase/Google online foundation. Native Google/Firebase Authentication, account restoration after restart, and own RTDB connection registration were verified against the development project. Team/room server APIs remain undeployed. See [verification and remaining work](docs/VERIFICATION_2026-11-02.md).

## Scope boundaries

- **Implemented:** Home, Training, History Calendar, Battle, Team, Achievements and Settings navigation; home action links; explicit saving/deleting of local workout sessions, recorded rest days, exercise-day streaks, atomic on-device JSON persistence in Application Support (with legacy UserDefaults migration), camera selection, Apple Vision pose inference (best-effort 12fps), skeleton, counter and diagnostics, framework-independent core tests, experiment checklist.
- **Optional online foundation:** dedicated Google account screen, verified native Firebase login/Keychain restoration and own RTDB connection flags. Enable with `FITBOSS_FIREBASE_ENABLED=1`; supply local SDK config, Apple Development signature and a matching macOS profile as documented in setup. Callable teams/rooms, daily participation ranking, uploads and the final-offline trigger have emulator coverage but are not deployed.
- **Not implemented:** visual game screens, character designs, achieved badges, sit-ups, squats, planks, hold timers.
- These future areas will be built in separate branches/modules while pose evaluation is tested. See [UI MVP](docs/UI_MVP.md) and [online contract](docs/ONLINE_DATA_SPEC.md).

## macOS requirements

- macOS 14 or later and Apple Xcode / Command Line Tools with Swift 5.9+.
- A built-in/USB/Continuity Camera, and camera permission.
- Default build has no Firebase dependency. Optional online build uses official Firebase and Google SDKs and local configuration described in [setup](docs/FIREBASE_SETUP.md).

## Run

```sh
git clone https://github.com/asukamiyachi/FitBOSS.git
cd FitBOSS
swift test
./Scripts/build-app.sh
open .build/FitBOSS.app
```

This camera lab is an experimental prototype, not a finished product. GitHub Actions automatically runs `swift test` and the app build on **macOS** for pull requests and pushes to `main`. A launchable .app bundle must be built on macOS; CI does not test camera hardware. The script generates an ad-hoc-signed local test application; distributing a production app requires proper Apple signing/notarization. The default macOS green window control enters full screen. A camera can be changed via the picker. Use the "カウントリセット" button to reset the experimental count.

If camera permission is denied, open System Settings > Privacy & Security > Camera. A stable side-angle camera position gives this 2D elbow-angle heuristic its best chance; try moving slowly and comfortably.

## Local workout history

Completed workout summaries and explicit rest days are stored as a JSON file under the user's **Application Support/FitBOSS** directory. Updates use atomic file replacement so the previous file remains intact if writing fails. Legacy UserDefaults history is migrated only after the file is successfully saved. If loading or saving fails, further writes are disabled rather than silently overwriting data; the UI shows a storage error. Workout calendar dates, session times, and streak calculations consistently use **Asia/Tokyo (JST)** even if the Mac displays another time zone. This file is not synchronized with Firebase.

## Privacy and measurement limitations

All captured video is processed locally, never saved or sent anywhere. The optional online build sends completed workout summaries and connection/progress values through authenticated APIs. Camera frames and landmarks remain on this Mac. The generated counts are experimental—not a validated assessment of correct form or health. Tracking may be inaccurate for occlusion, front-facing cameras, mirrored images, uneven lighting and very fast motion.

See [Architecture](docs/ARCHITECTURE.md) and [Experiment plan](docs/EXPERIMENT_PLAN.md). The independent `FitBOSSCore` package is intentionally ready for future rep- and duration-based evaluators.
