# FitBOSS Camera Lab

macOS native SwiftUI / AVFoundation / Apple Vision experimental exercise tracker.

## Download for macOS

![Download for macOS — Coming soon](https://img.shields.io/badge/Download_for_macOS-Coming_soon-lightgrey?logo=apple)

**No public download yet.** FitBOSS does not currently have a Developer ID–signed and Apple-notarized DMG in [GitHub Releases](https://github.com/asukamiyachi/FitBOSS/releases). The disabled badge is intentionally **not a link**. The internal GitHub Actions artifact is for development testing, not general distribution.

The permanent one-click download button, to **enable only after the first verified public Release contains `FitBOSS.dmg`**, is prepared below:

<!-- ENABLE ONLY AFTER A SIGNED AND NOTARIZED PUBLIC RELEASE CONTAINS FitBOSS.dmg
[![Download for macOS](https://img.shields.io/badge/Download_for_macOS-FitBOSS.dmg-black?logo=apple)](https://github.com/asukamiyachi/FitBOSS/releases/latest/download/FitBOSS.dmg)
-->

When the public button is enabled, clicking it downloads the latest `FitBOSS.dmg`. Open the DMG, then drag `FitBOSS.app` into the **Applications** shortcut. GitHub README buttons cannot directly copy apps to a user's Applications directory.

See [macOS distribution & release safety](docs/MACOS_DISTRIBUTION.md) for setup.

## Current phase

Camera access and selection, live full-screen-capable preview, local human-body pose landmarks, skeleton overlay, and a deliberately simple *experimental* 2D push-up repetition evaluator. Not a finished coaching or game product.

## Scope boundaries

- **Implemented in main:** camera permission and camera selection, Vision pose inference, skeleton, counter and diagnostics, independent core and synthetic unit tests.
- **Not merged:** additional UI and Firebase online features in PR #3 and PR #4. This distribution PR does not modify either.
- Camera images and joint landmarks remain on-device in the current camera-only build.

## macOS requirements

- macOS 14 or later and Apple Xcode / Command Line Tools with Swift 5.9+.
- A built-in, USB or Continuity Camera, and permission to use it.

## Run locally

```sh
git clone https://github.com/asukamiyachi/FitBOSS.git
cd FitBOSS
swift test
./Scripts/build-app.sh
open .build/FitBOSS.app
```

## Create an internal test DMG

```sh
bash Scripts/build-app.sh
bash Scripts/create-dmg.sh
```

This creates `.build/dist/FitBOSS.dmg` with `FitBOSS.app` and a shortcut to `/Applications`. It is **ad-hoc signed and not notarized**. The PR's GitHub Actions workflow saves it only as a short-lived **internal artifact**. Production distribution requires Developer ID signing, hardened runtime, notarization and stapling, and is blocked until these succeed.

GitHub Actions builds the macOS app for pull requests and pushes to main; CI does not verify camera hardware. If permission is denied, open System Settings > Privacy & Security > Camera.

## Privacy and measurement limitations

Captured video is processed locally and never saved or sent anywhere by the camera prototype on main. Push-up counts are experimental 2D estimates, not validated exercise coaching. Results may be inaccurate because of occlusion, camera angles or lighting.

See [Architecture](docs/ARCHITECTURE.md), [Experiment plan](docs/EXPERIMENT_PLAN.md) and [Distribution](docs/MACOS_DISTRIBUTION.md).
