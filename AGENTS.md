# Agent guidance for FitBOSS

- This repository intentionally starts with a camera/pose experiment, NOT a game.
- Do not implement bosses, scoring battles, online matches, accounts, leaderboards, teams, or Firebase without a separately approved scope.
- Keep FitBOSSCore independent of SwiftUI, AVFoundation, Vision, Firebase and network calls.
- Keep camera frames and landmarks on-device; never persist/upload raw video or images.
- Preserve the exercise-agnostic ExerciseEvaluator interface for future repetition and hold-duration activities.
- Run `swift test` and, on macOS, `./Scripts/build-app.sh` when possible. Document what was not actually tested.
- Do not merge PRs to main without explicit authorization.
