# FitBOSS online contract — proposed MVP architecture

**Design only. Not implemented or deployed.** Work independently of camera PR #1 and keep GitHub Actions **manual only**.

**Authentication decision:** Google Sign-In only for cloud features in this development stage, using Firebase Auth `uid` as the canonical identity. Local camera/solo use does not require a login. Never grant team/room access based only on Google email or display name. Reassess alternative provider requirements before Mac App Store submission.

## Two flows

### A. Solo workout

1. The Mac estimates posture and tracks an exercise entirely **on device**.
2. When the user presses **Finish**, produce an immutable result with a client-generated UUID `sessionId` and `completedAt`.
3. Store the completed result in a durable local **pending-sync queue** (planned). If online, submit once; if offline, retry when reconnected.
4. Server validates identity, membership, timestamps, event ID/idempotency and numeric bounds. **Do not trust client score as proof of movement.** Mark as provisional when unverified.
5. Persist one session in Firestore under the stable ID; calculate the team daily aggregate asynchronously. A retry must never count twice.
6. During solo exercise, **do not publish frame-by-frame or live repetition counts**.

### B. Live room (1–6 participants)

1. Signed-in user creates an invitation-only room. Default cap: **6 distinct users**.
2. Participants join via expiring, non-guessable invitation token/code. Server checks identity, active membership, capacity and room status **transactionally**; room metadata is authoritative.
3. Room state: `waiting → active → finished` or `cancelled`. A participant has `joined / ready / active / disconnected / finished / left`.
4. When active, each Mac pushes only limited ephemeral progress, no image/pose stream: `metricType`, `value`, `status`, `updatedAt`. Initial target: **at most once per second** per participant; throttle, validate bounds, and back off when disconnected.
5. Clients observe the six-user snapshot; intermittent progress is provisional. Reconnect preserves identity and previously acknowledged room state.
6. Completing a room persists **one immutable session per participant** through the same result pipeline as solo mode.
7. Do not transfer participants' camera feeds. Do not rank different units (repetitions vs seconds) directly.
8. For an initial implementation, room joins and finalization should be mediated by trusted server logic; server-side cap/security validation is required.

## Online member state

- **Online** means the user's FitBOSS app is connected to Firebase and has registered presence; it does **not** mean they are exercising, visible on camera or available for a match.
- Realtime Database `presence/{uid}/connections/{connectionId}` has one entry per active device/connection. Use `/.info/connected` and register `onDisconnectRemoveValue` **before** publishing online.
- `presence/{uid}/lastSeenAt` is server timestamp of last disconnect, visible only to authorized teammates (privacy settings can disable this).
- A user is offline when no active connections remain; presence is eventually consistent and can be briefly stale after crashes/network loss.
- RTDB access requires trusted team membership ACL replication or a server-mediated access path. **No broad authenticated-user reads**.

## Permanent data proposal (Firestore)

```txt
users/{uid}
  displayName, privacy, createdAt
teams/{teamId}
  name, ownerUid, createdAt, archived
teams/{teamId}/members/{uid}
  role: owner|member, joinedAt, displayName
workoutSessions/{sessionId}
  uid, teamId?, exerciseId, metricType, value, completedAt,
  receivedAt, source: solo|live, roomId?, verificationStatus, schemaVersion
teams/{teamId}/dailyStats/{YYYY-MM-DD}
  dateKey, timezone, updatedAt
teams/{teamId}/dailyStats/{YYYY-MM-DD}/exercises/{exerciseId}/members/{uid}
  completedSessions, countTotal?, durationSeconds?, cappedGoalProgress?, updatedAt
```

Unique team membership rules must be decided before deploy. `dateKey` uses the exercise's completion time in the agreed timezone **Asia/Tokyo**, with policy for delayed uploads at midnight. The server, not the client's raw count, owns aggregate writes.

## Ephemeral data proposal (Realtime Database)

```txt
presence/{uid}/connections/{connectionId}
presence/{uid}/lastSeenAt
rooms/{roomId}/metadata
  hostUid, teamId?, exerciseId, metricType, phase, capacity: 6, createdAt
rooms/{roomId}/participants/{uid}
  status, value, updatedAt, metricType
roomAccess/{roomId}/{uid}
  allowed: true  (trusted backend-managed ACL)
teamAccess/{teamId}/{uid}
  allowed: true  (trusted backend-managed ACL)
```

Never allow a user to set another person's `uid`, arbitrarily join rooms, increase room capacity, modify access ACLs or finalize other users' results. Apply retention rules and expire finished rooms.

## Intensity, comparisons, and well-being

- `value` is the exercise's native metric (repetitions or hold seconds). No combined unit-free score initially.
- Avoid claiming 2D elbow angle is physiological **intensity**; if desired later, separate `difficultyTier` (chosen exercise variant) and `movementQuality` (experimentally estimated). Labels should never imply medical-grade certainty.
- Match people within the same exercise/conditions, and avoid unsafe escalation of difficulty or volume to win.
- Team progress uses opted-in goals, **bounded** achievement and participation rather than encouraging unlimited repetitions. Rest days should not lower an individual's ranking.
- Team data remains private to invited members; allow non-discoverable profiles and hiding online status.

## Contracts for later integration

```txt
ExerciseResult (FitBOSSCore, local)
  → WorkoutSessionDraft (local sync queue)
  → WorkoutSessionSubmission (trusted API)
  → WorkoutSessionRecord (Firestore)
  → TeamDailyAggregate (Firestore)

ExerciseResult (local) → LiveProgress (RTDB ephemeral)
```

Backend session finalization is deferred until the client SDK, authentication, and security rules are implemented. This PR intentionally adds **no** Firebase Swift SDK, Cloud Functions, game code, automated workflows or cloud deployment.

## Acceptance tests (before production)

- Solo: end session offline, reboot, reconnect, upload exactly once; do not double-count retries.
- Solo: finish just before/after midnight JST, verify the correct daily bucket.
- Presence: two devices per user, close one then both; crash and reconnect; hidden-presence preference.
- Rooms: sixth join succeeds, seventh denied; concurrent joins cannot overfill capacity.
- Security: cross-team read rejected; unauthenticated request rejected; forged uid and room score changes rejected.
- Live: six participants, ≤1 update/second/user, temporary disconnect, resume, authoritative finish.
- Privacy: no raw camera frames or pose landmarks leave macOS.
