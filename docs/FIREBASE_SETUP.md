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
3. **User screenshot confirmed:** The Apple app was registered under `com.asukamiyachi.FitBOSS` (matches `Resources/Info.plist` on camera PR #1), and the initial `GoogleService-Info.plist` was downloaded locally. After enabling Google as a provider, **download an updated plist**. Do not commit the downloaded file for now. Apple app settings: https://console.firebase.google.com/project/fitboss-acde2/settings/general .
4. **Google Sign-In only (user reports enabled; not independently verified):** In **Authentication → Sign-in method**, verify **Google** is enabled and the project support email is set. Leave Email/Password, Anonymous, Apple, and other sign-in providers disabled for the initial private testing scope. After enabling Google, **download a fresh `GoogleService-Info.plist`** from the Apple app settings; do not commit it. macOS native integration will use `GoogleSignIn-iOS` (which also supports macOS), `FirebaseAuth`, the browser redirect URL scheme from `REVERSED_CLIENT_ID`, and Keychain entitlements/signing. Test the login flow on a real Mac before release.
5. **User reports completed (configuration not independently verified):** Create **Cloud Firestore** in **Production mode** with initially closed rules. Proposed region **`asia-northeast1` (Tokyo)** for Japan-based usage if available. The instance region cannot be changed later. The un-deployed repository rules deny all.
6. **User reports completed (configuration not independently verified):** Create **Realtime Database** in **locked mode**. Proposed available Asian region **`asia-southeast1` (Singapore)**. Do not assume Tokyo is available for Realtime Database; select a region from its own offered list. This instance region cannot be changed later.
7. **Do not deploy functions or switch billing plans yet.** Plan Cloud Functions and costs only when a concrete backend action is needed. Consider budget alerts before upgrading.
8. Project ID received: **`fitboss-acde2`**. Do not share passwords, service-account JSON or access tokens. The Apple configuration file can remain local.

## Config included in this PR

- `firebase.json` lists Firestore/Realtime Database rules, empty Firestore indexes and local emulators.
- `firebase/firestore.rules` and `firebase/database.rules.json` **DENY ALL** client reads and writes. These are safe placeholders, **not usable product access rules**.
- `.firebaserc` has only the **`dev` alias** set to `fitboss-acde2`; there is deliberately no `default` alias, reducing the chance of unintentionally targeting a cloud project. Any later deploy must explicitly select the project after security tests and review.
- Camera PR #1 has passed macOS CI and merged. Keep the camera-only Swift target independent of Firebase; introduce a separate Firebase service layer in a later PR.

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
| Apple app registration | Confirmed by user-provided screenshot |
| Authentication provider | User reports Google enabled and support/public name configured; not independently verified |
| Cloud Firestore instance | User reports created; edition, region and current rules not independently verified |
| Realtime Database instance | User reports created; region and current rules not independently verified |
| Firebase Swift SDK in macOS app | Not added |
| Security Rules deployment | Not done |
| GitHub Actions | Automatic CI for pull requests and `main` enabled on 2026-11-02; no Firebase deployment |

Firebase Apple SDK references (2026): https://firebase.google.com/docs/ios/setup and https://firebase.google.com/docs/ios/learn-more .

## Google-only sign-in decision (2026-11-02)

- **Authentication providers:** User reports Google enabled; settings are not independently verified. No Email/Password, anonymous or Apple in the current plan.
- **Stable identifier:** Use the verified Firebase Auth `uid` as the principal; do not use email address, display name, or Google photo URL as primary keys, room authorization or team membership references.
- **Minimum account data:** Only store required app profile fields. Keep private email/photo out of room broadcasts and public rankings.
- **On macOS:** Google Sign-In uses the default browser and a redirect URL; register the reversed client ID URL scheme and correctly configured Keychain access group. Do not assume iOS-specific presentation code builds for macOS.
- **Local guest use:** The camera-only exercise lab should remain usable without signing in; Google login gates cloud synchronization/teams/rooms, not the on-device camera. This prevents mandatory account creation for basic exercises.
- **App Store distribution:** Apple's current App Review Guideline 4.8 may require an equivalent privacy-preserving alternative when a general-audience app uses Google as the primary third-party sign-in, unless a stated exception applies. Re-evaluate before Mac App Store distribution; **Google-only is a private-development decision, not a guarantee of App Store approval**.
- **Account lifecycle:** Plan in-app account deletion and team-data handling before publishing.

Official references:
- https://firebase.google.com/docs/auth/ios/google-signin
- https://github.com/google/GoogleSignIn-iOS
- https://developer.apple.com/app-store/review/guidelines/

## Service creation confirmation (user report, 2026-11-02)

The user reports Google Authentication, Firestore and Realtime Database setup completed in the Firebase Console for `fitboss-acde2`. This is **not** independent verification of provider settings, regions, Security Rules, or billing plan.

Before any live app data is written:
1. Verify Firestore and RTDB rules deny all client access (locked/prod default) in the Firebase Console. Repository Rules have NOT been deployed.
2. Confirm Firestore/RTDB instance locations from Console, rather than relying on recommended locations.
3. Refresh `GoogleService-Info.plist` after enabling Google sign-in, keeping the downloaded file local.
4. Write and test least-privilege membership/room Rules in Firebase Emulators. Never simply turn on `read/write = true`.
5. Decide team membership, presence visibility, invitations, and result-validation contracts before building synchronization.
