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
- [x] Privacy policy matches the code: profile photos in Firestore, possible legacy
      activity covers in Firebase Storage, Firebase Analytics, reports/blocks and terms acceptance.
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
- [x] Set `CFBundleDisplayName` to "Hang Out" in `ios/Runner/Info.plist`;
      added `NSPhotoLibraryUsageDescription` + `NSAppleMusicUsageDescription`
      (file_picker links those APIs → ITMS-90683 without them).
- [x] **Toolchain.** Requires Flutter ≥ 3.47 (built with 3.47.7; older can't
      build iOS with `firebase_auth` 6.7.0). Gradle 8.14.3 + AGP 8.11.1.
      `Podfile.lock` on Firebase SDK 12.19.0. iOS uses CocoaPods
      (`enable-swift-package-manager: false` in `pubspec.yaml`, because
      file_picker 11.x's Swift package doesn't resolve).
- [ ] Verify `targetSdk` meets Play's current minimum target API level.
- [x] README updated (no longer claims "mock only").
- [ ] Commit the regenerated app icons (already on disk, uncommitted).
- [x] Tighten `firestore.rules` (list scoping, field-level writes, chat/message
      membership, handshake-verified friend/circle joins) — see Security below.
- [ ] **Publish** `firestore.rules` in the Firebase console and **create the composite
      index** from `firestore.indexes.json` (`activities`: `circleId` ASC + `startAt` ASC).
      Without the index the Discover feed query fails.
      (Re-publish after the city filter: rules now validate the optional
      `city` field, max 60 chars, and let hosts edit it.)
- [x] City filter on Discover: options come from cities of live activities;
      new activities require a City. Activities created before this have no
      city and only show under "All cities". Distance filter is deferred (it
      needs location permission + privacy label updates).
- [x] Story card: activity details → Share → "Share as story" exports a
      1080×1920 PNG ("I'm going to…" + QR + link) via the share sheet; also
      offered in a snackbar right after joining. Hidden for circle activities.
      Generated on-device, no new data collected (no privacy label change). The
      QR/link only works once Hosting is deployed (`/a/<id>`).
- [x] Host edit / cancel: activity details → ⋯ → "Edit details" (title,
      category, description, place, city, time; cover not editable) or "Cancel
      hangout" (soft cancel, one-way). Only before the start time. Cancelled
      hangouts leave Discover, can't be joined, show "Cancelled" in Hangouts and
      a banner on details; members get a line in the group chat.
      **Requires re-publishing `firestore.rules`** (new `cancelled` field,
      `updated`/`cancelled` system messages).
- [x] Hangouts rows and activity chat headers observe local activity changes
      immediately, including edited titles and cancelled status.
- [x] Other participants see host edits/cancellations live (Firestore listeners
      on Hangouts, activity details and activity chat headers). Hangouts shows
      a retry state if it can't load.
- [x] Chat sends are WhatsApp-style: clock while sending, single check once the
      server has it, "Not sent. Tap to retry." on failure (long-press to
      delete). Client-generated message ids prevent duplicate retries. No
      delivered/read receipts.
- [x] Profile image selection opens Photos on iOS; other platforms retain the
      filtered file picker. New activities no longer offer cover uploads.
      Photo permission text also explains saving story images.
- [x] Selected profile photos are resized, saved to the user profile and restored
      on reopening. Sign-in preserves the saved avatar; failed saves show an error.
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
- [x] **Shareable activity links** (`https://hang-out-129b5.web.app/a/<id>`): the share
      message includes the link; tapping it opens the hangout in the app (Android App
      Link + `hangout://activity/<id>` scheme), or a landing page in `hosting/public/`.
- [ ] **Deploy the link landing page:** `firebase deploy --only hosting` (free on Spark).
- [ ] **Android App Link verification:** add the **Play App Signing** SHA-256 (Play
      Console → Setup → App signing) and the upload key SHA-256 to
      `hosting/public/.well-known/assetlinks.json`, then redeploy hosting. It currently
      only lists the debug key, so release builds open links via the landing page.
- [ ] **iOS links (needs paid Apple account):** set `APP_STORE_URL` in
      `hosting/public/a.html`; optionally add Universal Links (Associated Domains
      `applinks:hang-out-129b5.web.app` + `apple-app-site-association` with Team ID).
      Until then iOS opens links through the landing page's `hangout://` button.

## C. Store forms — declare data consistently

Both stores require you to declare data collection, and it MUST match the privacy
policy. Declare exactly this:

| Data type | Collected? | Linked to user | Purpose |
|---|---|---|---|
| Name | Yes | Yes | App functionality |
| Email address | Yes | Yes | App functionality, account management |
| User ID | Yes | Yes | App functionality |
| Photos (Google avatar, uploaded avatar; legacy activity covers where retained) | Yes | Yes | App functionality |
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
- [ ] Add **Sign in with Apple** before submitting (guideline 4.8 requires it when you
      offer a third-party sign-in like Google). Step-by-step: `docs/APPLE_SIGN_IN_SETUP.md`.

## Verification (before submitting)
- [ ] `flutter analyze` clean.
- [ ] In Firebase Authentication, confirm Email/Password is enabled. On a real
      device, verify account creation, email delivery and verification, sign-in,
      password reset, and password confirmation when deleting an account.
- [ ] Publish the updated `firestore.rules` in the Firebase console. Until then,
      email verification is enforced by the app but not by those backend rules.
- [ ] If retaining a Blaze-enabled bucket for older activity covers, review and
      publish `storage.rules` separately. The current app does not upload covers.
- [ ] Publish the updated privacy policy and terms where they are hosted.
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
