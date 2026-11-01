# FitBOSS MVP UI shell

## Scope

This is the first **replaceable** macOS SwiftUI layout, not the final visual design.
User approved UI scaffolding on 2026-11-02.

### Navigation

| View | Included in UI | Actual behavior |
| --- | --- | --- |
| ホーム | Streak, battle summary, team, badge, recent activity | Empty real-data states, functional navigation; adaptive card grid |
| トレーニング | Camera lab and push-up prototype | Preserved working camera behavior from old ContentView |
| 対戦 | Room code, room creation, battle history | Invite-code input and join/create are disabled until secure Firebase service exists |
| チーム | Invite code, online teammates, team ranking | Invite-code input and membership creation disabled; no pretend presence |
| 実績 | Four illustrative badge types | All labeled unearned; no fake awards |
| 設定 | Account and privacy explanations | Google login disabled until SDK exists |

### Architecture and guardrails

- \`ContentView.swift\` owns navigation and simple read-only placeholder screens.
- \`WorkoutCameraView.swift\` owns the unchanged experimental camera lab; \`CameraManager\` stays local and exists only while the workout page is shown.
- No Firebase SDK, online connections, fake leaderboard/presence, hardcoded user records, analytics or outgoing camera data.
- Never claim an online team/match exists until confirmed by an authenticated backend.
- Do not equate client-computed repetition count with verified movement or clinical quality.
- Streaks must be rest-day-aware; badges and leaderboards must not reward unsafe escalation of training.
- Future Firebase services should be injected behind an interface, replace unavailable UI controls with real actions only after auth, Rules, and room-capacity tests are complete.
- Keep Google-only login as a *development* decision. Review App Store sign-in requirements before distribution.
- Use native SwiftUI components and SF Symbols for easier visual redesign later.

### Manual acceptance checklist

1. Launch app on macOS 14+; verify sidebar navigates all six destinations.
2. Home's three buttons open the corresponding screens.
3. First launch: all history/metrics remain empty; **no fabricated numbers**.
4. Join/create buttons, invite code inputs and Google login cannot submit or accept entries while backend absent.
5. Switching to Training starts camera and preserves preview, skeleton, push-up count, camera picker, error and reset behavior.
6. Navigating away stops capture, avoiding persistent background camera operation.
7. Match and team panels describe online status accurately and don't imply workout/camera visibility.
8. Resize the window to its minimum width; verify the home statistic cards reflow rather than shrinking into unreadable columns.
9. \`swift test\` and \`bash Scripts/build-app.sh\` pass on a macOS runner. Hardware camera / permission tests remain manual.
