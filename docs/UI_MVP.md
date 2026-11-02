# FitBOSS MVP UI shell

## Scope

This is the first **replaceable** macOS SwiftUI layout, not the final visual design.
User approved UI scaffolding on 2026-11-02.

### Navigation

| View | Included in UI | Actual behavior |
| --- | --- | --- |
| ホーム | Streak, battle summary, team, badge, recent activity | Locally persisted workouts shown as real recent activity/streak, otherwise empty states; adaptive grid |
| トレーニング | Camera lab and push-up prototype | Experimental camera behavior preserved; explicit completion button saves positive rep counts locally |
| 履歴カレンダー | Workout and rest-day marks, local session list and deletion | History file is on-device; completed session summaries may be uploaded while signed in and in a team |
| 対戦 | Room code, room creation, battle history | Default build is disabled; optional Firebase build implements authenticated callable team-room operations |
| チーム | Invite code, online teammates, team ranking | Default build is disabled; optional Firebase build provides team membership, presence summaries and rankings |
| 実績 | Four illustrative badge types | All labeled unearned; no fake awards |
| 設定 | Account and privacy explanations | Google login disabled until SDK exists |

### Architecture and guardrails

- \`ContentView.swift\` owns navigation, local-history dashboard, and read-only online placeholders.
- \`WorkoutCameraView.swift\` owns experimental camera capture and the explicit save action. \`WorkoutHistoryStore\` uses \`WorkoutHistoryPersistence\` to atomically save workout summaries and rest days as JSON in Application Support/FitBOSS. Existing UserDefaults history migrates only after a successful file write; corrupted history and I/O errors block later writes. \`WorkoutCalendarView\` renders and deletes records.
- Default build uses no Firebase SDK or networking. Optional `FITBOSS_FIREBASE_ENABLED=1` build includes Google/Firebase integrations and server-authorized summaries; no camera video or pose landmarks are uploaded. Cloud Functions are not deployed; Google sign-in and own presence registration were verified in the development project.
- Never claim an online team/match exists until confirmed by an authenticated backend.
- Do not equate client-computed repetition count with verified movement or clinical quality.
- Streaks must be rest-day-aware; badges and leaderboards must not reward unsafe escalation of training.
- History date keys, calendar month/day headings, and workout date/time labels use Asia/Tokyo regardless of the system display time zone.
- Firebase-enabled functions require Google authentication and server-side authorization. Emulator Rules and room-capacity tests exist, but cloud deployment and real Google login remain unverified.
- All windows share the app-owned workout history store; multiple windows must never overwrite one another's sessions or rest days.
- Keep Google-only login as a *development* decision. Review App Store sign-in requirements before distribution.
- Use native SwiftUI components and SF Symbols for easier visual redesign later.

### Manual acceptance checklist

1. Launch app on macOS 14+; verify sidebar navigates all seven destinations.
2. Home's three buttons open the corresponding screens.
3. First launch: history/metrics are empty; **no fabricated numbers**. Save a positive-count workout, confirm its count and streak appear on Home and calendar, then restart the app and verify local persistence. In the optional signed-in team workflow, verify the completion action discloses server upload of counts and timestamps.
4. Without configured Firebase, join/create/login cannot submit. In an authenticated optional Firebase build, verify errors, access restrictions and joined-team disclosures against the emulator before live deployment.
5. Switching to Training starts camera and preserves preview, skeleton, push-up count, camera picker, error and reset behavior.
6. Navigating away stops capture, avoiding persistent background camera operation.
7. Match and team panels describe online status accurately and don't imply workout/camera visibility.
8. Resize the window to its minimum width; verify the home statistic cards reflow rather than shrinking into unreadable columns.
9. Mark a past date as rest, confirm a workout date cannot also be marked rest; delete a saved session only after confirming the dialog. Verify stored summaries show the numeric count rather than a literal interpolation placeholder.
10. Verify local history still loads after upgrading from a UserDefaults-backed version; check error handling with corrupted history and blocked file writes. Verify date labels around JST midnight with the Mac set to another time zone.
11. \`swift test\` and \`bash Scripts/build-app.sh\` pass on a macOS runner. Hardware camera / permission tests remain manual.
