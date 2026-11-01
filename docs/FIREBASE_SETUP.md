# FitBOSS Firebase setup (development only)

**Status:** user reports that Firebase project `fitboss-acde2` was created on 2026-11-02. No authenticated console inspection, Apple app registration, service activation, cloud connection, or deployment has been performed by this PR.

## What is already decided

- macOS native application; app bundle ID from camera PR #1: `com.asukamiyachi.FitBOSS`.
- Firebase Authentication identifies a participant.
- Cloud Firestore persists teams, membership, completed workout sessions and dated aggregates.
- Realtime Database handles transient six-person room progress and team-member presence.
- Cloud Functions (later, if enabled) validates finalized results, manages invitations and computes aggregates. A client-computed count alone cannot prove the exercise was performed.
- No video, photographs, body joint streams or detailed biometric data sent to Firebase.
- No online logic, Firebase dependency or game UI added to the camera PR.

## Console checklist (user action)

1. **Reported completed by user:** Created development Firebase project ID `fitboss-acde2`. Console: https://console.firebase.google.com/project/fitboss-acde2/overview . This ID is a public project identifier, not a secret; project existence/ownership has not been independently verified. Keep production separate.
2. Google Analytics: user chose to keep the project-level Analytics setting on. This does **not** mean an Analytics SDK is installed in the macOS app. Decide event collection/notice/opt-out before adding the SDK; avoid logging camera images, pose landmarks, or detailed workout health signals.
3. **Not yet confirmed:** Register an **Apple** app at https://console.firebase.google.com/project/fitboss-acde2/settings/general using exact case-sensitive bundle ID `com.asukamiyachi.FitBOSS` (matches `Resources/Info.plist` on camera PR #1). Optional app nickname: `FitBOSS macOS Dev`. Leave App Store ID blank. Download `GoogleService-Info.plist` for later local integration. Do not commit the downloaded file for now.
4. **Not yet confirmed:** In **Authentication → Sign-in method**, configure an initial login method. For persistent multi-device team membership, **Email/Password** is an uncomplicated starting choice. Use accounts made for testing, and consider email-verification policy before sharing invitations; Firebase macOS Authentication support is partial, so test the selected provider specifically. Anonymous test accounts can be upgraded by linking credentials later.
5. **Not yet confirmed:** Create **Cloud Firestore** in **Production mode** with initially closed rules. Proposed region **`asia-northeast1` (Tokyo)** for Japan-based usage if available. The instance region cannot be changed later. The un-deployed repository rules deny all.
6. **Not yet confirmed:** Create **Realtime Database** in **locked mode**. Proposed available Asian region **`asia-southeast1` (Singapore)**. Do not assume Tokyo is available for Realtime Database; select a region from its own offered list. This instance region cannot be changed later.
7. **Do not deploy functions or switch billing plans yet.** Plan Cloud Functions and costs only when a concrete backend action is needed. Consider budget alerts before upgrading.
8. Project ID received: **`fitboss-acde2`**. Do not share passwords, service-account JSON or access tokens. The Apple configuration file can remain local.

## Config included in this PR

- `firebase.json` lists Firestore/Realtime Database rules, empty Firestore indexes and local emulators.
- `firebase/firestore.rules` and `firebase/database.rules.json` **DENY ALL** client reads and writes. These are safe placeholders, **not usable product access rules**.
- `.firebaserc` has only the **`dev` alias** set to `fitboss-acde2`; there is deliberately no `default` alias, reducing the chance of unintentionally targeting a cloud project. Any later deploy must explicitly select the project after security tests and review.
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

## Cloud setup status checklist (not independently verified)

| Item | Status |
| --- | --- |
| Firebase project `fitboss-acde2` | User reports created |
| Apple app registration | Not confirmed |
| Authentication provider | Not confirmed |
| Cloud Firestore instance | Not confirmed |
| Realtime Database instance | Not confirmed |
| Firebase Swift SDK in macOS app | Not added |
| Security Rules deployment | Not done |
| GitHub Actions | Manual-only workflow on `main`, not modified by this branch |

Firebase Apple SDK references (2026): https://firebase.google.com/docs/ios/setup and https://firebase.google.com/docs/ios/learn-more .
