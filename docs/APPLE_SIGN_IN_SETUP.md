# Sign in with Apple — setup guide (from zero)

How to add **Sign in with Apple** to Hang Out (iOS) when you don't yet have an
Apple Developer account. Do the phases in order. Parts marked **you** are
manual (web consoles, Xcode); the code changes in Phase 5 can be done by the agent.

| | |
|---|---|
| Bundle ID | `com.raresrosu.hangout` |
| Firebase project | `hang-out-129b5` |
| Stack | Flutter, `firebase_auth` 6.x (already has Apple support — **no new package needed**) |

## Why this is required

- **App Store Guideline 4.8 (Login Services):** the app offers Google sign-in, so
  it must also offer an equivalent privacy-friendly login. Sign in with Apple is
  the standard way to meet that.
- **Guideline 5.1.1(v) (Account deletion):** when a Sign in with Apple user
  deletes their account, the app must also **revoke their Apple tokens** (Apple
  REST API). Firebase does this for you via `revokeTokenWithAuthorizationCode`,
  but only if Phase 3's key is configured.

## Timeline & cost

| Phase | Who | Time |
|---|---|---|
| 0. Apple Account ready | you | 10 min |
| 1. Enroll in Apple Developer Program | you | 15 min + **24–48 h** approval (can be up to ~2 weeks) |
| 2. Apple portal: App ID + key | you | 20 min |
| 3. Firebase console | you | 10 min |
| 4. Xcode capability | you | 10 min |
| 5. Code changes | agent | 1–2 h |
| 6. Test on a real iPhone | you + agent | 1 h |
| 7. App Store Connect / review | you | 1–2 h |

Cost: **$99 USD/year** (or local-currency equivalent). Covers all your apps.

---

## Phase 0 — Prepare your Apple Account (you)

1. Pick the Apple Account (Apple ID) that will **own the app long-term**. Moving
   apps between accounts later is possible but painful. A personal account you
   control is fine.
2. Make sure **two-factor authentication** is on (iPhone: Settings → your name →
   Sign-In & Security).
3. The name on the Apple Account must match your **government photo ID**
   exactly (no nicknames). Mismatches are the #1 cause of enrollment delays.
4. Have a **payment card in your own name**.

### Individual or Organization?

| | Individual | Organization |
|---|---|---|
| Seller name on the App Store | your legal name | your company name |
| Needs | photo ID | legal entity (e.g. SRL), free **D-U-N-S number**, website, work email |
| Approval | ~24–48 h | ~2–4 weeks |
| Team members | no | yes |

**Recommendation:** enroll as **Individual** now (this matches
`docs/RELEASE_CHECKLIST.md`). If you form a company later, Apple Support can
convert the membership to an organization.

> **EU note (you're in Romania):** to distribute in the EU, App Store Connect
> makes you declare **trader status** under the Digital Services Act. If you
> monetize (ads, subscriptions, in-app purchases), you're almost certainly a
> trader, and your **address, phone and email are shown publicly** on the
> App Store. Using a company, or a business address and phone, avoids exposing
> your home details.

---

## Phase 1 — Enroll in the Apple Developer Program (you)

1. Easiest path: install the **Apple Developer** app on your iPhone (it can scan
   your ID). Alternatively go to <https://developer.apple.com/programs/enroll/>.
2. Sign in with the Apple Account from Phase 0 → **Account** → **Enroll Now**.
3. Choose **Individual / Sole Proprietor**. Enter your legal name, address and
   phone. Complete ID verification if asked.
4. Pay the $99 fee.
5. Wait for the **"Welcome to the Apple Developer Program"** email.
6. Go to <https://developer.apple.com/account> and accept any pending
   agreements.
7. Note your **Team ID**: developer.apple.com/account → **Membership details**.
   It's a 10-character code like `AB12CD34EF`. You'll need it in Phase 3.

> The project currently has `DEVELOPMENT_TEAM = 6BXVJJRL4U`. That is most likely
> a free **Personal Team**, which **cannot** use Sign in with Apple. It will be
> replaced by your new paid Team ID in Phase 4.

---

## Phase 2 — Apple portal: App ID + Sign in with Apple key (you)

Go to <https://developer.apple.com/account/resources> (Certificates,
Identifiers & Profiles).

### 2.1 Register the App ID

1. **Identifiers** → **+** → **App IDs** → **App** → Continue.
2. Description: `Hang Out`.
3. Bundle ID: **Explicit** → `com.raresrosu.hangout` (must match exactly).
4. Under **Capabilities**, tick **Sign in with Apple** and keep **"Enable as a
   primary App ID"**.
   - Optional now, needed later: tick **Associated Domains** (for universal share
     links; `docs/RELEASE_CHECKLIST.md` L122–124).
5. **Continue** → **Register**.

If Xcode already created this App ID, open it, tick **Sign in with Apple** and
then **Save**.

> If Apple says the bundle ID is unavailable, someone else owns it. You'd have
> to choose a new ID and update it in Xcode **and** in Firebase (new iOS app plus
> a new `GoogleService-Info.plist`). Ask the agent to do that change.

### 2.2 Create the Sign in with Apple key (for token revocation)

1. **Keys** → **+**.
2. Key name: `Hang Out Sign in with Apple`.
3. Tick **Sign in with Apple** → **Configure** → Primary App ID:
   `com.raresrosu.hangout` → **Save**.
4. **Continue** → **Register** → **Download** the `.p8` file.
   - ⚠️ **You can download it only once.** Store it in a password manager.
   - ⚠️ **Never commit it to git** or paste it into chats or issues.
5. Note the **Key ID** (10 characters, shown on the key page).

### 2.3 What you can skip

- **Services ID:** not needed for iOS-only sign-in. You only need it if you later
  add Apple sign-in on Android or the web.
- **Email relay ("Sign in with Apple for Email Communication"):** only needed if
  the app **sends emails** to users. Hang Out doesn't today. Users who choose
  "Hide My Email" get a `…@privaterelay.appleid.com` address. If you send email
  later, register your sending domain or address there first, or the relay drops
  your messages.

---

## Phase 3 — Firebase console (you)

1. <https://console.firebase.google.com> → project **hang-out-129b5** →
   **Authentication** → **Sign-in method** → **Add new provider** → **Apple**.
2. Toggle **Enable**.
3. **Services ID:** leave empty (not required for Apple platforms).
4. **OAuth code flow configuration**, which is required for token revocation:
   - **Apple team ID:** from Phase 1, step 7.
   - **Key ID:** from Phase 2.2.
   - **Private key:** open the `.p8` in a text editor and paste the **entire**
     contents, including the `-----BEGIN PRIVATE KEY-----` and `END` lines.
5. **Save**.
6. Check **Authentication → Settings → User account linking**. Keep the default,
   **"Link accounts that use the same email"** (one account per email). Effect:
   if someone first signed in with Google as `x@gmail.com` and later taps Apple
   while sharing the same real email, Firebase returns
   `account-exists-with-different-credential`. The app will tell them to use
   Google (Phase 5). Users who pick "Hide My Email" get a separate account.

---

## Phase 4 — Xcode (you)

1. **Xcode → Settings → Accounts → +** → Apple Account → sign in with the
   enrolled account. Your team should show as **"Your Name (Individual)"**, not
   "(Personal Team)".
2. Open `ios/Runner.xcworkspace` (the **workspace**, not the `.xcodeproj`).
3. Select the **Runner** target → **Signing & Capabilities**:
   - **Automatically manage signing:** on.
   - **Team:** your paid team.
   - **Bundle Identifier:** `com.raresrosu.hangout`.
4. Click **+ Capability** → **Sign in with Apple**.
   - This creates `ios/Runner/Runner.entitlements` containing
     `com.apple.developer.applesignin = [Default]`. It also sets
     `CODE_SIGN_ENTITLEMENTS` in the project.
   - Check the capability appears for **Debug, Release and Profile** (use the
     "All" tab at the top of Signing & Capabilities).
5. Build once (⌘B) so Xcode creates the provisioning profile with the new
   capability.
6. Commit `ios/Runner/Runner.entitlements` and `ios/Runner.xcodeproj/project.pbxproj`.
   These contain no secrets.

---

## Phase 5 — Code changes (agent; you can start this before approval)

The code can be written and unit-tested now. It only needs the paid account to
run on a device. Planned changes:

1. **`AuthService`**: add `signInWithApple()`, plus the mock and emulator
   variants so the existing tests and the emulator e2e setup keep working.
2. **`FirebaseAuthService.signInWithApple()`**: uses Firebase's native iOS
   flow, with no extra package:
   ```dart
   final provider = AppleAuthProvider()
     ..addScope('email')
     ..addScope('name');
   await _auth.signInWithProvider(provider);
   ```
   - Treat the user closing the Apple sheet as a no-op, not an error.
   - Show a clear message for `account-exists-with-different-credential`
     ("You already have an account with Google, continue with Google").
3. **Don't wipe names (existing bug that Apple users would hit):**
   `_mirrorIdentity()` writes `user.displayName ?? ''` on **every** sign-in.
   - Apple sends the user's name **only on the very first authorization** and
     never again.
   - So a returning Apple user, or one with no name, would get their profile name
     blanked.
   - Fix: never overwrite an existing profile name with an empty one.
4. **Sign-in screen**: add a **"Continue with Apple"** button on iOS.
   - Use a black or white button with the Apple logo, per Apple's design rules
     (Human Interface Guidelines).
   - It must be **at least as prominent** as the Google button (same size, no
     lower placement).
5. **Account deletion with token revocation** (required by 5.1.1(v)). For users
   whose `providerData` includes `apple.com`:
   ```dart
   final cred = await user.reauthenticateWithProvider(AppleAuthProvider());
   final code = cred.additionalUserInfo?.authorizationCode;
   if (code != null) await _auth.revokeTokenWithAuthorizationCode(code);
   await user.delete();
   ```
   - The reauthentication (a Face ID prompt) must happen **before**
     `AccountDeletionService` starts deleting data. Today the cascade deletes
     data first and the login last.
   - Otherwise, cancelling the Apple prompt would leave a half-deleted account.
   - This also avoids `requires-recent-login` for Apple users.
6. **Sign-out**: only call Google's `signOut()` when the user actually signed in
   with Google.
7. **Privacy policy and terms**:
   - Add Apple as a sign-in provider (what Apple shares: name and email, or a
     relay email).
   - State that Apple access is revoked when the account is deleted.
8. **Tests**: unit tests for the name-preservation rule, the provider-specific
   deletion order, and Apple sign-out.

---

## Phase 6 — Test on a real iPhone (you + agent)

Sign in with Apple on the **Simulator** works only if the simulator is signed in
to an Apple Account, and even then it's unreliable. Use a real device.

1. iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
2. Connect it by cable and trust the Mac. Xcode registers the device
   automatically (automatic signing).
3. Run `flutter run -d <your-iphone>` (`flutter devices` lists it).

Test checklist:

- [ ] First sign-in, **share my email**: the name appears in the profile and in chats.
- [ ] First sign-in, **Hide My Email**: works, and the name still shows.
- [ ] **Cancel** the Apple sheet: back on the sign-in screen, no error.
- [ ] **Log out → sign in again**: the name is **not** wiped (Phase 5, step 3).
- [ ] **Delete account**:
  - Face ID prompt appears, then you're back on the sign-in screen.
  - **Revocation check:** on the iPhone go to Settings → your name →
    **Sign-In & Security → Sign in with Apple**. "Hang Out" must no longer be
    listed.
- [ ] Sign in with Apple **again after deletion**: Apple shows the first-time
  sheet asking for name and email again. This also proves the revocation worked.
- [ ] Google user with the same email taps Apple: friendly "use Google" message.

To reset during testing, open Settings → your name → Sign-In & Security →
Sign in with Apple → Hang Out → **Stop Using Apple ID**.

---

## Phase 7 — App Store Connect & review (you)

1. <https://appstoreconnect.apple.com> → **Apps → + → New App**:
   - Platform **iOS**; name **Hang Out**. App names must be unique on the store,
     so have backups like "Hang Out – Meet & Do".
   - Bundle ID `com.raresrosu.hangout`; SKU e.g. `hangout-ios-001`.
2. Build and upload:
   - Run `flutter build ipa --release`, then upload
     `build/ios/ipa/*.ipa` with the **Transporter** app (or Xcode Organizer).
   - Test with **TestFlight** (internal testers) before submitting.
3. **App Privacy** questionnaire: declare email address and name (linked to
   the user, used for app functionality, not for tracking). Also declare
   user-generated content, photos and so on, as covered in
   `docs/RELEASE_CHECKLIST.md`.
4. **Age rating**: answer yes to user-generated content and messaging between users.
5. **Review notes**: reviewers can use their own Apple ID, but still include:
   - A **Google demo account**, since Google sign-in is the other path.
   - "Account deletion: Profile → Delete account (revokes Sign in with Apple)."
   - "Report/block: in chats and profiles. Reports are reviewed within 24 h."
6. Items unlocked by the paid account (see `docs/RELEASE_CHECKLIST.md`
   L122–124):
   - Set `APP_STORE_URL`.
   - Add Associated Domains `applinks:hang-out-129b5.web.app` and publish the
     `apple-app-site-association` file with your Team ID.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| "Sign in with Apple" missing in **+ Capability** | Team is a **Personal Team**. Select the paid team (Phase 4, step 3). |
| `AuthorizationError 1000` / sheet closes immediately | Entitlement missing from the provisioning profile: re-add the capability and rebuild. On the Simulator: not signed in to an Apple Account. |
| `invalid-credential` / "Invalid OAuth response from apple.com" | Apple provider not enabled in Firebase, or the bundle ID doesn't match the App ID. |
| Account deletion fails with `invalid_client` on revoke | Wrong Team ID, Key ID or `.p8` in Firebase, or the key isn't linked to `com.raresrosu.hangout`. |
| `account-exists-with-different-credential` | Same email already used with Google: expected (Phase 3, step 6). |
| Name empty after Apple sign-in | Apple only sends the name the first time. Revoke ("Stop Using Apple ID") and retry. Check Phase 5, step 3 is in. |

## References

- Apple: [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/) ·
  [App Review Guidelines 4.8 and 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/) ·
  [TN3194: account deletion and token revocation](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple) ·
  [Enrollment](https://developer.apple.com/programs/enroll/)
- Firebase: [Authenticate using Apple (Apple platforms)](https://firebase.google.com/docs/auth/ios/apple) ·
  [Flutter federated auth](https://firebase.google.com/docs/auth/flutter/federated-auth)
