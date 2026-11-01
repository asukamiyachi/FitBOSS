# FitBOSS Camera Lab

macOS native SwiftUI / AVFoundation / Apple Vision experimental exercise tracker.

**Current phase:** camera access and selection, live full-screen-capable preview, local human-body pose landmarks, skeleton overlay, and a deliberately simple *experimental* 2D push-up repetition evaluator. Not a finished coaching or game product.

## Scope boundaries

- **Implemented in this PR:** camera permission + built-in/external/Continuity camera selection, preview, Vision pose inference (best-effort 12fps), skeleton, counter & diagnostics, framework-independent core, 9 synthetic unit tests, experiment checklist.
- **Not implemented:** online matches, Firebase, team registration, leaderboards, game UI, character designs, data storage, sit-ups, squats, planks, hold timers.
- These future areas will be built in separate branches/modules while pose evaluation is tested.

## macOS requirements

- macOS 14 or later and Apple Xcode / Command Line Tools with Swift 5.9+.
- A built-in/USB/Continuity Camera, and camera permission.
- No external runtime dependencies or Firebase configuration in the current prototype.

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

## Privacy and measurement limitations

All captured video is processed locally, never saved or sent anywhere. No networking is implemented. The generated counts are experimental—not a validated assessment of correct form or health. Tracking may be inaccurate for occlusion, front-facing cameras, mirrored images, uneven lighting and very fast motion.

See [Architecture](docs/ARCHITECTURE.md) and [Experiment plan](docs/EXPERIMENT_PLAN.md). The independent `FitBOSSCore` package is intentionally ready for future rep- and duration-based evaluators.
