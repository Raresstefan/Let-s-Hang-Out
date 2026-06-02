# Hang Out 🎉

A cross-platform (iOS · Android · Web) social app that helps people meet up and do
activities together — drinks, tennis, coffee, food, whatever. It's built to reduce the
social anxiety of meeting new people: browse activities others created, join with one tap,
and land straight in a group chat to plan.

> Built with Flutter. This first version runs entirely on **mock in-memory data**, so it
> launches with zero backend setup. The whole app is coded against repository abstractions,
> so swapping in Firebase later touches only the composition root — not the screens.

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

### Run

```bash
# Web (fastest, no native toolchain needed)
flutter run -d chrome

# iOS simulator (requires Xcode)
flutter run -d ios

# Android emulator (requires Android SDK)
flutter run -d android
```

To list available devices: `flutter devices`.

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
│   ├── analytics/analytics_service.dart   # Hang:* event abstraction + console impl
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
test/feed_smoke_test.dart           # boots the app, asserts feed + filter work
```

---

## Analytics convention

Call sites never touch a vendor SDK — they call typed helpers on `AnalyticsService`, which
enforces the naming pattern and de-duplication:

| What | Event | Helper |
|------|-------|--------|
| Activity rendered (once each) | `Hang:${activity_title}:OnLoad` | `analytics.activityOnLoad(title, activityId: id)` |
| Button click | `Hang:${button_name}:Clicked` | `analytics.buttonClicked('join_activity')` |
| Input typing (once per input) | `Hang:${input_name}:Typing` | `analytics.inputTyping('activity_title')` |
| Service success | `Hang:${action}:Success` | `analytics.actionSuccess('createActivity')` |

In debug mode events print to the console (`📊 [analytics] …`). To ship to a real backend,
implement `AnalyticsService` (e.g. `FirebaseAnalyticsService`) and pass it in `main.dart`.

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
3. Implement `FirestoreActivityRepository` against the existing `ActivityRepository`
   contract, and a `FirebaseAnalyticsService` against `AnalyticsService`.
4. In `lib/core/config/app_config.dart` set `useMockBackend = false` and wire the real impls
   in `main.dart`. No screen code changes.

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
