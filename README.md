# Hang Out 🎉

A cross-platform (iOS · Android · Web) social app that helps people meet up and do
activities together — drinks, tennis, coffee, food, whatever. It's built to reduce the
social anxiety of meeting new people: browse activities others created, join with one tap,
and land straight in a group chat to plan.

> Built with Flutter. The app runs on a live **Firebase** backend by default
> (Google Sign-In + Cloud Firestore; project `hang-out-129b5`) — set via
> `useMockBackend = false` in `lib/core/config/app_config.dart`. The whole app is
> coded against repository abstractions, so it can still run fully on **mock
> in-memory data** with zero backend setup by flipping that flag to `true`.

---

## Quick start

### Prerequisites
- [Flutter](https://docs.flutter.dev/get-started/install) 3.35+ (`flutter --version`)
- For **web**: Google Chrome (works out of the box)
- For **iOS**: Xcode + CocoaPods (`sudo gem install cocoapods`)
- For **Android**: Android Studio + SDK command-line tools, then `flutter doctor --android-licenses`

Verify your setup:
```bash
flutter doctor
```

### Install dependencies
```bash
flutter pub get
```

### Run — step by step

1. **Check your toolchain is healthy:**
   ```bash
   flutter doctor
   ```
   Fix any `[✗]` lines for the platform you plan to target before continuing (a
   `[!]` warning is usually fine to ignore).

2. **Install dependencies** (skip if you just did it above):
   ```bash
   flutter pub get
   ```

3. **Pick a target device.** See what Flutter can already see:
   ```bash
   flutter devices
   ```
   - **Web** → Chrome is always listed, no extra setup needed.
   - **iOS** → open the Simulator app once (`open -a Simulator`) so it shows up in the list.
   - **Android** → an emulator must be *booted* first — see the dedicated
     [Android emulator walkthrough](#running-the-android-emulator-from-the-command-line) below
     if none is running yet.

4. **Run the app**, targeting whichever device you chose:
   ```bash
   # Web (fastest, no native toolchain needed)
   flutter run -d chrome

   # iOS simulator (requires Xcode)
   flutter run -d ios

   # Android — use the exact device id from `flutter devices`, e.g. emulator-5554
   flutter run -d emulator-5554
   ```
   The first run compiles native code and can take a few minutes (Android's
   Gradle build in particular). Subsequent runs are much faster.

5. **Use the running session.** While `flutter run` is attached in your terminal:
   - `r` — hot reload (fast, keeps app state) — for widget/logic tweaks
   - `R` — hot restart (re-runs `main()`) — needed after editing JSON/assets,
     `main.dart`, providers, or app-root wiring
   - `q` — quit and stop the app

> Note: `flutter run` needs an interactive terminal attached — if it's launched
> detached/backgrounded with no TTY, the debug/VM-service connection can drop
> shortly after launch ("Lost connection to device"). Run it in a normal
> foreground terminal you keep open.

### Running the Android emulator from the command line

If you'd rather not use Android Studio's UI, you can launch the emulator and run
the app entirely from the terminal.

**One-time: put the Android SDK tools on your PATH** (add to `~/.zshrc`):
```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```
Then `source ~/.zshrc` (or open a new terminal).

**List the available virtual devices (AVDs):**
```bash
emulator -list-avds
```

**Launch an emulator (visible window):**
```bash
# Replace Pixel_8_API_35 with one from the list above.
# Run in the background so the terminal stays free; -no-snapshot = clean cold boot.
emulator -avd Pixel_8_API_35 -no-snapshot -gpu auto &
```
> Don't pass `-no-window`/`-qt-hide-window` — those launch it headless (no visible
> screen). Plain `emulator -avd <name>` shows a normal window.

**Wait until it's fully booted, then confirm it's online:**
```bash
adb wait-for-device
adb devices          # should show: emulator-5554   device
```

**Run the app on it:**
```bash
flutter run                      # auto-picks the only running device
# or target it explicitly:
flutter run -d emulator-5554
```

**Hot reload — yes, it works here.** While `flutter run` is attached, the terminal
accepts the interactive keys:
- `r` — **hot reload** (fast, keeps app state) — for widget/logic tweaks
- `R` — **hot restart** (re-runs `main()`) — needed after editing JSON/assets,
  `main.dart`, providers, or app-root wiring
- `q` — quit (stops the app)

**Shut the emulator down when done:**
```bash
adb -s emulator-5554 emu kill
```

Troubleshooting:
- `flutter devices` shows nothing but `adb devices` shows the emulator → the iOS/
  Xcode probe is failing; run `sudo xcodebuild -license accept` once to silence it.
- "Error opening emulator" → an instance of that AVD is already running (e.g. one
  Android Studio launched headless). Kill it first: `adb emu kill` or
  `pkill -f qemu-system`.

### App icon / logo

The launcher icon (Android/iOS/web) is generated from `assets/logo/app_icon.png` via
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons), configured in
`pubspec.yaml`. `assets/logo/logo.png` (mark + wordmark) is the in-app logo shown in the
Discover screen's app bar.

To replace the logo:
1. Drop the new square, icon-only artwork at `assets/logo/app_icon.png` (and the full
   mark+wordmark version at `assets/logo/logo.png` if it changed too).
2. Regenerate the launcher icons:
   ```bash
   dart run flutter_launcher_icons
   ```

### Test & analyze
```bash
flutter test        # widget/unit tests
flutter analyze     # static analysis / lints
```

### Build release artifacts
```bash
flutter build web        # -> build/web
flutter build apk        # Android
flutter build appbundle  # Android (Play Store upload)
flutter build ios        # iOS (then archive in Xcode for App Store)
```

---

## What's implemented in this first version

- **Discover feed** — scrollable list of activity **Cards**, each with a cover image
  background, title, and the current number of people enrolled (per the design spec).
- **Emoji filter bar** — tap an emoji (🍺 🎾 ☕ 🍔 🎵 ⚽) to filter the feed to that
  category; tap the active one again to clear the filter.
- **Bottom menu** — Discover · Friends · **`+` (centre, highlighted FAB)** · My Activities ·
  Profile. The `+` opens the create-activity flow.
- **Create activity** — host enters title, description, place suggestion, start date/time,
  category, and an optional cover image.
- **Join** — one tap to join an activity (updates the enrolled count).
- **My Activities / Friends / Profile** — screens scaffolded (Friends/Profile stubbed
  pending the backend + social graph).
- **Analytics instrumentation** — wired from day one (see below).
- **Localization** — all UI text comes from `assets/i18n/en_US.json`.

### Not yet wired (next milestones)
Group chat, host accept/deny join requests, host removing members, friend graph & friend
chat, activity ratings, the 2-hours-before push reminder, and AI recommendations. These all
depend on the real backend — see the roadmap below.

---

## Project structure

```
lib/
├── main.dart                       # Composition root — picks mock vs real impls
├── app.dart                        # MaterialApp + Provider dependency graph
├── core/
│   ├── config/app_config.dart      # useMockBackend flag
│   ├── analytics/                 # Event abstraction + Firebase/console impls
│   ├── l10n/app_localizations.dart # JSON-backed dot-notation localization
│   └── theme/app_theme.dart        # App theme (warm coral palette)
├── domain/models/                  # Activity, AppUser, ActivityCategory
├── data/repositories/
│   ├── activity_repository.dart    # abstraction
│   └── mock_activity_repository.dart   # in-memory seeded implementation
└── features/
    ├── home/        # bottom-nav shell with the highlighted centre FAB
    ├── feed/        # discover feed, activity card, emoji filter bar
    ├── create/      # create-activity form
    ├── my_activities/, friends/, profile/

assets/i18n/en_US.json              # all UI strings
assets/logo/logo.png                # full logo (mark + wordmark), used for branding contexts
assets/logo/app_icon.png            # square icon-only mark — source for the launcher icon
test/feed_smoke_test.dart           # boots the app, asserts feed + filter work
```

---

## Analytics convention

Call sites never touch a vendor SDK — they call typed helpers on `AnalyticsService`, which
enforces stable Firebase-compatible names and de-duplication:

| What | Event | Helper |
|------|-------|--------|
| Content rendered (once each) | `content_viewed` (`content_name`, `activity_id`) | `analytics.activityOnLoad(title, activityId: id)` |
| Button click | `button_clicked` (`button_name`) | `analytics.buttonClicked('join_activity')` |
| Input typing (once per input) | `input_started` (`input_name`) | `analytics.inputTyping('activity_title')` |
| Service success | `action_succeeded` (`action_name`) | `analytics.actionSuccess('createActivity')` |

Firebase mode sends events through `FirebaseAnalyticsService`; mock mode prints them to the
console. To inspect Android events in Firebase **Analytics → DebugView**, run:

```bash
adb shell setprop debug.firebase.analytics.app com.hangout.hangout
```

Disable DebugView routing with
`adb shell setprop debug.firebase.analytics.app .none`.

---

## Localization convention

All visible text lives in `assets/i18n/en_US.json` as nested JSON and is read with
dot-notation keys, with `{name}` interpolation:

```dart
final l = AppLocalizations.of(context);
l.tr('activity.placeholder.title');                 // input placeholder
l.tr('activity.enrolledCount', {'count': 5});       // -> "5 enrolled"
```

To add a language, drop a new `assets/i18n/<locale>.json` (e.g. `ro_RO.json`), add the
`Locale` to `supportedLocales` in `app.dart`, and extend `isSupported` in the localization
delegate.

---

## Wiring the real backend (Firebase)

Chosen stack: **Firebase** (Auth, Cloud Firestore, Cloud Messaging, Storage). It covers all
the product's needs — real-time group chat, activity storage, image uploads, and push
notifications — with a generous free tier and pay-as-you-go scaling.

1. `flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging firebase_storage firebase_analytics`
2. `dart pub global activate flutterfire_cli && flutterfire configure` (generates
   `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`).
3. In `lib/core/config/app_config.dart` set `useMockBackend = false`; `main.dart` then wires
   the Firestore repositories and `FirebaseAnalyticsService`. No screen code changes.

---

## Cost & technology rationale (criterion #6)

| Concern | Choice | Why |
|---------|--------|-----|
| Backend / DB / chat / auth | **Firebase** (Firestore + Auth + Storage) | Real-time chat at free-tier scale; no servers to run. Costs grow only with usage. |
| Push notifications (incl. the 2h-before reminder) | **Firebase Cloud Messaging** | Free, cross-platform. The reminder is best scheduled server-side (Cloud Function) so it fires even when the app is closed. |
| Analytics events | **Firebase Analytics** (free, unlimited events) behind our `AnalyticsService` abstraction | No per-event cost; swap to PostHog later without touching call sites if we need richer product analytics. |
| A/B testing (future) | **Firebase Remote Config + A/B Testing** | Free, already in the stack; no extra vendor. |
| AI activity recommendations (future) | Start rule-based ("most joined / highest rated"); later a lightweight model or hosted LLM fed by Firestore engagement data | Defer ML cost until there's data; the `isSuggested`/`likeCount` fields already model the surface. |
| Distribution | Google Play (`appbundle`) + App Store (`ipa` via Xcode) | One Flutter codebase ships to both stores. |

---

## License
Private project — all rights reserved.
