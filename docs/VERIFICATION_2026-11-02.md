# Online foundation follow-up (2026-11-02)

## Changes

- Integrated PR #3 through `e8db5d2` without rewriting history. Atomic workout file persistence, legacy migration protection and JST labels remain intact.
- Split SDK-invalid path rejection from Security Rules rejection. `bad:path` is an SDK-valid key denied by the connection ID rule.
- Presence now lives at `presence/{uid}/connections` and `presence/{uid}/summary`. The server transacts over their common user parent; it checks current connections before committing a last-offline timestamp. Only a nonempty-to-empty event can initiate reconciliation. RTDB event time makes duplicate and older deliveries idempotent. Readers derive online status from the current connection set in the same read as the summary; an unprocessed disconnect displays unknown until reconciled.
- The Database trigger uses the event's database instance, avoiding default-instance mismatch. Emulator triggers use us-central1, the emulator's default namespace region. Cloud remains asia-southeast1 pending independent region verification.
- Room creation checks every invitee in its transaction. Room join checks the invite, membership and capacity inside one transaction.
- Upload queue v2 uses atomic files bound to both UID and team; restored records cannot transfer to another account or team. Acknowledgment removes the queue item only after success. In-flight session IDs suppress overlapping resends. Backend UUID idempotency protects crash-before-ack retries.
- Read callbacks reject responses from an old account/team/room. Logout clears cached member, ranking and room data. Permission failures clear displayed private data. Ranking refresh retains the selected period.
- Visible, foreground Battle screen polls room progress at most every 3 seconds; failures back off to 60 seconds and overlapping reads are suppressed. This is polling, not push. At six continuously viewing members the upper bound is 120 callable reads/minute per room plus progress writes, without retries. Team overview uses one RTDB read per member rather than two. Validate actual billing/latency before live use.
- Firebase builds use an explicit Swift compilation condition. Cached SDK modules no longer accidentally enable parts of networking in a subsequent local-only build.

## Local checks

- Swift core: 24 tests, including atomic history/legacy migration, JST midnight, upload restart/account binding and corrupt queue protection.
- Normal release app and optional Firebase/Google SDK debug compilation.
- Node domain: 7 tests and syntax checks.
- Emulator Security Rules: 3 cases covering direct Firestore denial and allowed/denied RTDB writes and reads.
- Auth/Functions/Firestore/RTDB integration: Google and anonymous/unauthenticated calls, cross-team access, forged UID, expired invites, withdrawal, concurrent sixth/seventh entry, progress ownership, duplicate workout submission and daily de-duplication, rematch without auto-enrollment, real Database trigger, two devices, final disconnect, stale/duplicate reconciliation, reconnect and real client onDisconnect, concurrent reconnect from a second database connection.
- CI runs these emulator checks automatically. See PR #4 checks for latest remote results.

## Limits and next work

- No Firebase deployment, billing change, main merge, real Google login or camera hardware test occurred.
- Downloads plist matches project and bundle but lacks CLIENT_ID, REVERSED_CLIENT_ID and DATABASE_URL. It was neither copied into the repository nor printed. A newly downloaded configuration after enabling Google is required for real login; proper signing/Keychain still needs verification.
- Existing v1 upload map has no owner UID. Preserve it in UserDefaults; do not silently attribute it to the next signed-in account. No v1 map is deleted or uploaded automatically. Migration needs explicit account attribution. New v2 entries work independently.
- History completion and queue enqueue are two atomic writes, not one combined transaction. A crash between them can leave a saved session unqueued. Logged-out/teamless completions remain local; joining a team does not retroactively share history. Product/UI consent and recovery for such records remain work.
- Backend currently accepts completions only within seven days. Older queue entries remain pending and fail validation; expiry/recovery UI is pending.
- Local deletion cancels pending upload but does not erase an already uploaded record or day aggregate. An in-flight upload can complete after local deletion. Server deletion/retention/account lifecycle are not implemented.
- Emulator restart while clients remain connected, real process kill, OS sleep, logout/token expiry and long-duration reconnection need additional end-to-end tests. Socket closure is covered, not every OS failure mode.
- Live RTDB URL, Firestore edition/location, deployed Rules and billing plan remain unverified. Confirm these and trigger region before any approved deployment.
- Membership checks prevent new calls after withdrawal; requests already executing at withdrawal and data already received cannot be recalled. Cross-service Firestore/RTDB operations have no shared transaction.
- Dependency installation reports npm advisories (including transitive packages). Review upgrades separately before deployment; no forced major update was applied.

References: [RTDB transactions](https://firebase.google.com/docs/database/admin/save-data), [Database trigger location](https://firebase.google.com/docs/functions/database-events), [presence and onDisconnect](https://firebase.google.com/docs/database/web/offline-capabilities).
