# FitBOSS (macOS prototype)

macOS native SwiftUI / AVFoundation / Apple Vision experimental exercise tracker.

**Current phase:** a native SwiftUI seven-screen prototype with camera/pose tracking and **local-only workout history**. Home can show saved push-up sessions and exercise-day streaks, and a history calendar records workouts and rest days on this Mac. Battle, Team, Achievements and Settings are presentation-only; no Google authentication, Firebase app SDK, team join, badge progression or online play is wired yet. No fabricated records are displayed.

## Scope boundaries

- **Implemented:** Home, Training, History Calendar, Battle, Team, Achievements and Settings navigation; home action links; explicit saving/deleting of local workout sessions, recorded rest days, exercise-day streaks, atomic on-device JSON persistence in Application Support (with legacy UserDefaults migration), camera selection, Apple Vision pose inference (best-effort 12fps), skeleton, counter and diagnostics, framework-independent core tests, experiment checklist.
- **Not implemented:** working Google login, online matches, Firebase app SDK/cloud sync, team registration, leaderboards, visual game screens, character designs, achieved badges, sit-ups, squats, planks, hold timers.
- These future areas will be built in separate branches/modules while pose evaluation is tested. See [UI MVP](docs/UI_MVP.md) and [online contract](docs/ONLINE_DATA_SPEC.md).

## macOS requirements

- macOS 14 or later and Apple Xcode / Command Line Tools with Swift 5.9+.
- A built-in/USB/Continuity Camera, and camera permission.
- No external runtime dependencies or Firebase SDK in the current app binary. A Firebase project and repository config are prepared independently, but there is no connection from the macOS app.

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

All captured video is processed locally, never saved or sent anywhere. No application networking is implemented. The generated counts are experimental—not a validated assessment of correct form or health. Tracking may be inaccurate for occlusion, front-facing cameras, mirrored images, uneven lighting and very fast motion.

See [Architecture](docs/ARCHITECTURE.md) and [Experiment plan](docs/EXPERIMENT_PLAN.md). The independent `FitBOSSCore` package is intentionally ready for future rep- and duration-based evaluators.
