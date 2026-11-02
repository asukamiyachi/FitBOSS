# Agent guidance for FitBOSS

- The first development track establishes an **experimental** camera/pose foundation, not a finished game.
- A separate, explicitly approved UI-only MVP shell was authorized on 2026-11-02: home, training, match, team, achievement and settings *screens* may be added, but must not imply the planned server features are operational.
- Do not implement actual bosses, competitive scoring, online matches, account registration, team membership, leaderboards or Firebase networking without separately implementing reviewed security and backend contracts.
- Keep FitBOSSCore independent of SwiftUI, AVFoundation, Vision, Firebase and network calls.
- Keep camera frames and landmarks on-device; never persist/upload raw video or images.
- Preserve the exercise-agnostic ExerciseEvaluator interface for future repetition and hold-duration activities.
- Do not invent user history, earned badges, member presence or results in placeholder UI. Label unfinished actions clearly.
- Rest and safe pacing are first-class; avoid rewarding excessive repetitions and do not penalize recovery days.
- Run \`swift test\` and on macOS \`./Scripts/build-app.sh\` when possible. Document tests that were not actually run.
- Do not merge PRs to main without explicit authorization.
