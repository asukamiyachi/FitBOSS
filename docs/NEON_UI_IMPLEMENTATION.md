# FitBOSS — neon fitness UI (first implementation)

## Scope and design intent

Implements a **Smart Fitness-inspired** dark navy, electric-blue and violet SwiftUI presentation for three screens without changing camera capture, exercise evaluation, workout storage, Firebase backend, or public distribution.

The generated visual concepts are **directional references, not literal screenshots of this PR**. This implementation uses native SF Symbols, SwiftUI gradients/cards and the existing live camera preview. No stock photos, fabricated workout history, fake opponents, countdown, or unimplemented "pause" control were added.

## Files

- \`BOSSDesignSystem.swift\`: reusable page/background, panels, status pills, metric cards and primary/secondary buttons.
- \`BOSSHomeScreen.swift\`: prominent workout CTA, existing workout streak, saved local sessions, privacy/network disclaimers. Battle and badges remain honest empty/unfinished states.
- \`BOSSBattleScreen.swift\`: gated login/team entry, real room state/provisional participant progress, actual room history, existing create/join/start/finish/rematch actions, copy invite code. Real Cloud Functions are still undeployed.
- \`WorkoutCameraView.swift\`: larger live preview, real count/confidence/angle, existing camera picker/start/stop/reset, explicit save confirmation, truthful pending online-summary disclosure.
- \`ContentView.swift\`: native sidebar grouped by the seven primary sections plus account; routes existing actions into the three new views. Existing timer-based room polling, foreground team refresh and upload retry logic remain untouched.

## Design tokens / components

- Canvas: \`Color(red:0.035,green:0.052,blue:0.105)\`.
- Surface: \`Color(red:0.085,green:0.105,blue:0.190)\`.
- Accents: electric cyan, violet and mint; primary action uses blue→violet gradient.
- Corner radius: 12–23pt; spacing primarily 12–26pt.
- Layout: scrollable main content; adaptive summary/detail grids and \`ViewThatFits\` transitions for narrow windows.
- Appearance: dark only in the three redesigned pages. Other app pages keep their prior native behavior and will be redesigned separately.
- Native accessibility: labeled buttons and camera selection, actual text for counts/status. No required custom gestures.

## Important product-state contracts

- Home uses actual local \`WorkoutHistory\` (or empty state); never displays sample sessions as user data.
- Training is a 2D single-arm experimental push-up counter, not an exercise-form validator.
- "完了して記録" saves a real positive-count session using the existing atomic history file store. Only after success does the UI display saved confirmation; in signed-in teams the existing upload queue and callable flow still run.
- No raw camera video or landmarks leave the Mac.
- Battle and team callables are still source/emulator-only; Cloud Functions are not deployed. Do not present a public online battle as available.
- Online participant progress is *provisional*, with visual bars relative to the largest currently returned count (not a verified winner, pace target, ranking or medical assessment).
- Mac multiwindow shared history and backend authorization controls must stay intact.

## Compact-window and review follow-up (2026-11-02)

- **820×540 window:** With a 170pt sidebar, the remaining detail width is below `BOSSLayoutPolicy.compactTrainingBreakpoint` (770pt). The training screen therefore displays **Save / Start–Stop / camera selector / reset above the preview**, not below a 442pt camera view. The preview is clamped to 220–320pt in compact mode. The same `@StateObject CameraManager` and `AVCaptureSession` survive layout changes; no extra camera pipeline is created. The `NSViewRepresentable` preview may be re-created across a width breakpoint; verify it visually on a real Mac.
- **Text and accessibility:** Narrow headings hide the nonessential FITBOSS wordmark; key training buttons are explicitly labeled, disabled controls remain visually dimmed, and the large numeric count has a descriptive accessibility value. Pose preview is excluded from the accessibility tree because it is purely visual; diagnostic text remains readable.
- **Battle information hierarchy:** When no room exists, Create/Join appears before empty current-room details (especially useful in a single-column narrow view). If a room exists, progress stays first. UI clears the invite input and selected invitees on UID/team changes and prunes members no longer present in the authorized member list. The UI prominently explains when online SDK, sign-in, or team membership is missing.
- **Deterministic tests:** `BOSSLayoutPolicyTests.swift` checks width crossover and short/normal/tall window preview heights. This **does not replace visual or camera hardware testing**.
- **Parallel PRs:** PR #6 `feat/beta-readiness` changes README, build/DMG scripts and CI but has **no direct changed-path overlap with PR #8**. PR #7 `refactor/readable-swift-ui-structure` splits the old Home/Battle implementations out of `ContentView.swift`; both PR #7 and PR #8 change that file and must be reconciled to prevent duplicated obsolete screens. Preferred integration is #7 first, then adapt #8's routing/design components to the refactored structure; **neither PR is merged here**.

## Acceptance checklist (manual macOS)

- [ ] Open new app in a small (at least 820×540) and a large window; no clipped buttons or inaccessible save control. Sidebar still navigates to account, home, workout, history, battle, team, achievements, settings.
- [ ] Start with no local history; home displays empty state, not invented records.
- [ ] Start/stop camera, switch devices, deny/grant permission, reset and record a positive count. Check correct saved feedback, restart and see it in Home/Calendar; on error, no success feedback.
- [ ] Confirm skeleton overlay/camera orientation visually on built-in and Continuity Camera if available, and that leaving training stops capture.
- [ ] Open two windows and verify both reflect saved/deleted/rest-day activity without stale overwrites.
- [ ] On offline build, battle actions are disabled and the development status is visible; no fabricated participants or rankings.
- [ ] For a future emulator/signed online build, verify signed-out, signed-in/teamless, joined-team, revoked-team, in-room and expired-invite states; the existing backend guards must still apply.
- [ ] Confirm VoiceOver labels, keyboard focus and contrast at different text sizes.
- [ ] \`swift test\`, \`bash Scripts/build-app.sh\`, and optional \`FITBOSS_FIREBASE_ENABLED=1 swift build -c debug --product FitBOSSApp\` pass in CI.

## Deliberately excluded

No real photo/banner asset has been committed; this pass uses native vector graphics and is intended as the first implementation of the visual direction. No changes to camera algorithm, local JSON schema, Firebase Rules/Functions, Cloud deployment, billing, Apple Developer ID signing, GitHub Release, or PR #6. No real-hardware test has been claimed.
