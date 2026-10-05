# Release Checklist — Hang Out

Working checklist for shipping to Google Play + Apple App Store as an **individual**
developer. Costs: Google Play **$25 one-time**, Apple **$99/year**. Docs hosting: free.

## 0. Before anything — fill in placeholders
- [x] Replace every `[CONTACT_EMAIL]` in `docs/privacy-policy.md`, `docs/terms.md`,
      `docs/index.md` with a real support email (`letshangout45@gmail.com`, also in-app
      under Profile → Help & contact).
- [x] Minimum age **18+** (terms, privacy policy, and the in-app agreement checkbox).
      Pick the matching age rating in both store questionnaires.

## A. Legal docs (blocker — collects personal data)
- [x] Privacy policy drafted → `docs/privacy-policy.md`
- [x] Terms of service drafted → `docs/terms.md`
- [ ] Host free via **GitHub Pages**:
      Repo → Settings → Pages → Source: "Deploy from a branch" → branch `main`,
      folder `/docs`. Save. URLs become:
      `https://<user>.github.io/<repo>/privacy-policy` and `.../terms`.
- [ ] Record the live HTTPS URLs (needed by both store consoles).
- [x] In-app "Delete account" action (Profile → Delete account).
- [x] Web account-deletion page for Google Play → `docs/delete-account.md`
      (`https://raresstefan.github.io/Let-s-Hang-Out/delete-account` once Pages is on).
      Enter it in Play Console → App content → Data safety → Delete account URL.
- [x] Privacy policy matches the code: uploaded photos (avatar in Firestore, activity
      covers in Firebase Storage), Firebase Analytics, reports/blocks, terms acceptance.
      Advertising-ID collection is disabled (Android manifest
      `google_analytics_adid_collection_enabled=false`; iOS Podfile
      `$FirebaseAnalyticsWithoutAdIdSupport = true`). If you add an SDK or start
      collecting a new data type, update the policy and both store forms.

## B. Project fixes
- [ ] **JDK for release builds.** Flutter's `jdk-dir` currently points at Android
      Studio's bundled JDK 25, which AGP 8.9.1 cannot parse (`IllegalArgumentException: 25.0.2`).
      Release builds succeed with **JDK 17** (Corretto 17 is installed). Either set
      `flutter config --jdk-dir "<path-to-jdk-17>"` or keep JDK 17 selected when building.
      Verified: `flutter build appbundle --release` builds `app-release.aab` under JDK 17.
- [x] Version unified in `pubspec.yaml` → `1.0.0+1` (Flutter propagates to both platforms).
- [x] Android release signing wired via `android/key.properties` (git-ignored).
- [x] `INTERNET` permission + display name "Hang Out" in AndroidManifest.
- [ ] **B1 — Reconcile bundle IDs.** Android `com.hangout.hangout` vs iOS
      `com.raresrosu.hangout`. Recommended: change iOS to `com.hangout.hangout`
      (matches Firebase Android registration). If you do:
      - [ ] Register `com.hangout.hangout` as an iOS app in the Firebase console.
      - [ ] Download the regenerated `GoogleService-Info.plist` and replace
            `ios/Runner/GoogleService-Info.plist`.
      - [ ] Update the reversed-client-id URL scheme + `GIDClientID` in
            `ios/Runner/Info.plist`.
      - [ ] Set `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`.
      (If you keep them separate, ensure BOTH IDs are registered in Firebase.)
- [ ] **B2 — Keystore.** Follow `android/key.properties.template`:
      generate the upload keystore, create `android/key.properties`, and register
      the upload key SHA-1 + SHA-256 in Firebase (so Google Sign-In works in release).
- [ ] Set `CFBundleDisplayName` to "Hang Out" in `ios/Runner/Info.plist`.
- [ ] Verify `targetSdk` meets Play's current minimum target API level.
- [x] README updated (no longer claims "mock only").
- [ ] Commit the regenerated app icons (already on disk, uncommitted).
- [x] Tighten `firestore.rules` (list scoping, field-level writes, chat/message
      membership, handshake-verified friend/circle joins) — see Security below.
- [ ] **Publish** `firestore.rules` in the Firebase console and **create the composite
      index** from `firestore.indexes.json` (`activities`: `circleId` ASC + `startAt` ASC).
      Without the index the Discover feed query fails.
- [x] User safety (store requirement — Apple 1.2 / Play UGC policy): report user /
      activity / message, block & unblock, host can remove a member (who can't rejoin).
- [x] Users must **accept the Terms + community rules** in-app (zero-tolerance wording)
      before using the app (`TermsGate`). After material Terms changes bump
      `kTermsVersion` in `lib/core/legal/legal.dart` so everyone re-accepts.
- [x] **Content filter** for objectionable language (`ContentFilter`): activity, circle,
      profile and custom-interest text is rejected. Chat is not filtered (report/block cover it). Client-side only —
      extend the word list in `lib/core/moderation/content_filter.dart` as needed.
- [ ] **Moderation process:** review the `reports` collection in the Firebase console
      at least daily (Apple expects action within 24h). Set `status` to `actioned` /
      `dismissed`; for abusive users disable the account in Firebase Auth. Mention
      the report/block tools in the App Review notes.

## C. Store forms — declare data consistently

Both stores require you to declare data collection, and it MUST match the privacy
policy. Declare exactly this:

| Data type | Collected? | Linked to user | Purpose |
|---|---|---|---|
| Name | Yes | Yes | App functionality |
| Email address | Yes | Yes | App functionality, account management |
| User ID | Yes | Yes | App functionality |
| Photos (Google avatar, uploaded avatar, activity cover images) | Yes | Yes | App functionality |
| Other user content (bio, interests, activities, chat messages, ratings, reports, block list) | Yes | Yes | App functionality, safety |
| App interactions / product interaction (Firebase Analytics events) | Yes | Not linked by us* | Analytics |
| Device or other IDs (Analytics app-instance ID) | Yes | Not linked by us* | Analytics |
| Approximate location (derived from IP by Analytics) | Check Firebase guidance* | — | Analytics |
| Precise location | No | — | — |
| Contacts | No | — | — |
| Advertising ID / tracking | No (disabled) | — | — |

\* Cross-check against Google's per-SDK guidance before submitting:
Play — https://firebase.google.com/docs/android/play-data-disclosure ;
Apple — https://firebase.google.com/docs/ios/app-store-data-collection .
The app never calls `setUserId`, so Analytics data isn't tied to the account by us.

- Encrypted in transit: **Yes**.
- Data deletion available: **Yes** — in-app (Profile → Delete account) and via the
  web page `delete-account`.
- No data used for tracking or advertising.
- Users can't use the app until they're 18+ (self-declared in the agreement).

### Google Play
- [ ] Register personal account ($25) + complete identity verification (gov ID).
- [ ] Create app, complete **Data safety** form per the table above.
- [ ] Add privacy policy URL + data-deletion URL.
- [ ] Content rating questionnaire, target audience, store listing (screenshots,
      description, feature graphic).
- [ ] Build AAB: `flutter build appbundle --release`.
- [ ] **Closed testing gate:** ≥12 testers opted in for ≥14 continuous days before
      production access. START THIS FIRST — it is the longest wait.

### Apple App Store
- [ ] Enroll in Apple Developer Program ($99/yr).
- [ ] Create app record in App Store Connect; complete **App Privacy** labels per
      the table above (must match Play + policy).
- [ ] Store listing: screenshots per device size, description, keywords, age rating.
- [ ] Build: `flutter build ipa` (or archive in Xcode) → upload via Transporter/Xcode.
- [ ] Submit for App Review. Provide a demo Google account for reviewers.
- [ ] If rejected under guideline 4.8: add **Sign in with Apple** (required when you
      offer a third-party sign-in like Google).

## Verification (before submitting)
- [ ] `flutter analyze` clean.
- [ ] `flutter build appbundle --release` and `flutter build ipa` both succeed.
- [ ] Install release AAB (internal testing track) + a TestFlight build on real
      devices → Google Sign-In works and Firestore reads/writes succeed
      (confirms release SHA is registered in Firebase).
- [ ] Privacy policy + terms URLs load over HTTPS.

## Security follow-ups
- Rules hardened and verified against the Firestore emulator (97 allow/deny cases):
  - Activities: field-level updates (host edit, self-join of upcoming only, self-leave,
    own like, own 1–5 rating by non-host members after start); circle hangouts
    readable only by circle members; Discover must query `circleId == null`.
  - Chats/messages: readable only by members; chat membership must match the backing
    activity/circle; messages require `senderId == me`; system lines are structured
    events whose names/titles are checked against real docs (no free-text spoofing).
  - `friend_requests/{from}_{to}` and `circle_invites/{circle}_{to}`: deterministic ids,
    party-scoped list/get; cross-user `friendIds` / circle `memberIds` self-add only
    with an accepted handshake doc.
  - Pre-existing test data with random-id requests/invites, or activities without a
    `circleId` field, won't work under the new rules — wipe test data before launch.
- Safety rules (emulator-verified, 40 cases): `blocks/{uid}` private to its owner;
  blocked users can't join the blocker's activities or send them friend requests /
  circle invites; `removedIds` only grows (host-only, ex-members only) and bars rejoin;
  `reports` are create-only with validated fields (no client reads).
- Add in-app account deletion.
