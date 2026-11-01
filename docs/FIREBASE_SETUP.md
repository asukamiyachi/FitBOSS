# FitBOSS Firebase setup (development only)

**Status:** prepared repository files; **no Firebase cloud project has been created, connected or deployed by this PR**.

## What is already decided

- macOS native application; app bundle ID from camera PR #1: `com.asukamiyachi.FitBOSS`.
- Firebase Authentication identifies a participant.
- Cloud Firestore persists teams, membership, completed workout sessions and dated aggregates.
- Realtime Database handles transient six-person room progress and team-member presence.
- Cloud Functions (later, if enabled) validates finalized results, manages invitations and computes aggregates. A client-computed count alone cannot prove the exercise was performed.
- No video, photographs, body joint streams or detailed biometric data sent to Firebase.
- No online logic, Firebase dependency or game UI added to the camera PR.

## Console checklist (user action)

1. Open https://console.firebase.google.com/ and create a **development** project. Choose your own unique project ID. Keep development and production in separate projects.
2. Review the Google Analytics option: it is **not required** for this MVP; avoid collecting analytics by default.
3. Register an **Apple** app with bundle ID `com.asukamiyachi.FitBOSS` (match `Resources/Info.plist` in camera PR #1). Download `GoogleService-Info.plist` for later use on macOS. Do not commit local config while initial setup is under review.
4. In **Authentication → Sign-in method**, configure the login method. Recommendation: start with test users; choose a stable sign-in method before persistent multi-device team membership. Anonymous test accounts can be upgraded by linking credentials later.
5. Create **Cloud Firestore** in the required region (select deliberately; location is not easily changed). Restrict all client access until Security Rules are tested.
6. Create **Realtime Database** in an available region near your users. Start in **locked** mode. The service's locations are not necessarily identical to Firestore regions.
7. **Do not deploy functions or switch billing plans yet.** Plan Cloud Functions and costs only when a concrete backend action is needed. Consider budget alerts before upgrading.
8. Provide the **project ID only**, not passwords, service-account JSON or access tokens, for the next integration step.

## Config included in this PR

- `firebase.json` lists Firestore/Realtime Database rules, empty Firestore indexes and local emulators.
- `firebase/firestore.rules` and `firebase/database.rules.json` **DENY ALL** client reads and writes. These are safe placeholders, **not usable product access rules**.
- No `.firebaserc` is created because no actual project ID is known.
- The camera-only Swift target must stay independent of Firebase; introduce a separate Firebase service layer later after PR #1 builds successfully.

## Safety gate before backend deployment

1. Define team roles and membership/invitation lifecycle, including leaving a team.
2. Apply least-privilege rules for one user's private session records and only their teams' data. Prevent editing other users' sessions or scoring.
3. Realtime Database rules cannot query Firestore membership directly. Use trusted server-maintained membership ACLs in Realtime Database, or enforce room reads/writes in a trusted backend.
4. Test Security Rules with the local Emulator Suite, including unauthorized read/write, tampering with teamId/uid, room capacity, replay, impersonation and cross-team data access.
5. Only then deploy explicit rules to the **development** project using an explicit `--project` argument.
6. Verify presence: add `onDisconnect` before writing online status, use a connection entry per device/session, and confirm cleanup after unexpected disconnects.
7. Confirm offline completion queue behavior, duplicate prevention, Japan-local midnight boundaries and user privacy controls.

## Local future commands (NOT executed)

```sh
npm install -g firebase-tools
firebase login
firebase emulators:start --project demo-fitboss --only auth,firestore,database
```

The `demo-` project ID is an emulator-only example, not your actual project. **Do not run `firebase deploy`** until project selection, allow rules, and security tests are approved. Firebase CLI can initialize the local project when needed; avoid overwriting this prepared `firebase.json`.

Documentation: https://firebase.google.com/docs/ios/setup · https://firebase.google.com/docs/database/ios/offline-capabilities · https://firebase.google.com/docs/rules
