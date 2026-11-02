# FitBOSS MVP UI shell

## Scope

This is the first **replaceable** macOS SwiftUI layout, not the final visual design.
User approved UI scaffolding on 2026-11-02.

### Navigation

| View | Included in UI | Actual behavior |
| --- | --- | --- |
| ホーム | Streak, battle summary, team, badge, recent activity | Locally persisted workouts shown as real recent activity/streak, otherwise empty states; adaptive grid |
| トレーニング | Camera lab and push-up prototype | Experimental camera behavior preserved; explicit completion button saves positive rep counts locally |
| 履歴カレンダー | Workout and rest-day marks, local session list and deletion | On-device session/rest persistence; no cloud sync |
| 対戦 | Room code, room creation, battle history | Invite-code input and join/create are disabled until secure Firebase service exists |
| チーム | Invite code, online teammates, team ranking | Invite-code input and membership creation disabled; no pretend presence |
| 実績 | Four illustrative badge types | All labeled unearned; no fake awards |
| 設定 | Account and privacy explanations | Google login disabled until SDK exists |

### Architecture and guardrails

- \`ContentView.swift\` owns navigation, local-history dashboard, and read-only online placeholders.
- \`WorkoutCameraView.swift\` owns experimental camera capture and the explicit save action. \`WorkoutHistoryStore\` uses \`WorkoutHistoryPersistence\` to atomically save workout summaries and rest days as JSON in Application Support/FitBOSS. Existing UserDefaults history migrates only after a successful file write; corrupted history and I/O errors block later writes. \`WorkoutCalendarView\` renders and deletes records.
- No Firebase SDK, online connections, fake leaderboard/presence, hardcoded user records, analytics or outgoing camera data.
- Never claim an online team/match exists until confirmed by an authenticated backend.
- Do not equate client-computed repetition count with verified movement or clinical quality.
- Streaks must be rest-day-aware; badges and leaderboards must not reward unsafe escalation of training.
- History date keys, calendar month/day headings, and workout date/time labels use Asia/Tokyo regardless of the system display time zone.
- Future Firebase services should be injected behind an interface, replace unavailable UI controls with real actions only after auth, Rules, and room-capacity tests are complete.
- Keep Google-only login as a *development* decision. Review App Store sign-in requirements before distribution.
- Use native SwiftUI components and SF Symbols for easier visual redesign later.

### Manual acceptance checklist

1. Launch app on macOS 14+; verify sidebar navigates all seven destinations.
2. Home's three buttons open the corresponding screens.
3. First launch: history/metrics are empty; **no fabricated numbers**. Save a positive-count workout, confirm its count and streak appear on Home and calendar, then restart the app and verify local persistence.
4. Join/create buttons, invite code inputs and Google login cannot submit or accept entries while backend absent.
5. Switching to Training starts camera and preserves preview, skeleton, push-up count, camera picker, error and reset behavior.
6. Navigating away stops capture, avoiding persistent background camera operation.
7. Match and team panels describe online status accurately and don't imply workout/camera visibility.
8. Resize the window to its minimum width; verify the home statistic cards reflow rather than shrinking into unreadable columns.
9. Mark a past date as rest, confirm a workout date cannot also be marked rest; delete a saved session only after confirming the dialog. Verify stored summaries show the numeric count rather than a literal interpolation placeholder.
10. Verify local history still loads after upgrading from a UserDefaults-backed version; check error handling with corrupted history and blocked file writes. Verify date labels around JST midnight with the Mac set to another time zone.
11. \`swift test\` and \`bash Scripts/build-app.sh\` pass on a macOS runner. Hardware camera / permission tests remain manual.

- All windows share the app-owned workout history store, so opening another window does not create a stale copy that overwrites newer local sessions or rest days.
