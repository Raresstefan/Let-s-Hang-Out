/// Global, compile-time-ish configuration switches for the app.
///
/// The whole app is built against repository *abstractions* (see
/// `lib/data/repositories`). When [useMockBackend] is true the app wires the
/// in-memory mock implementations, so it runs on web with zero Firebase setup.
/// Flip to false once Firebase is wired (see README "Wiring the real backend").
class AppConfig {
  AppConfig._();

  /// When true, use in-memory mock data instead of Firebase.
  static const bool useMockBackend = false;

  /// Debug-only: connect to local Firebase emulators (Auth, Firestore, Storage)
  /// loaded with this repo's rules, and sign in with a fake Google credential
  /// for [emulatorUserEmail]. Enable with
  /// `--dart-define=USE_FIREBASE_EMULATORS=true`; never set in release builds.
  static const bool useFirebaseEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
  );

  /// Host of the emulators. `10.0.2.2` is the host machine from an Android
  /// emulator.
  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  /// Email used for the fake Google sign-in in emulator mode.
  static const String emulatorUserEmail = String.fromEnvironment(
    'EMULATOR_USER',
    defaultValue: 'tester@example.com',
  );

  /// Default / starting locale. Only en_US is shipped for now.
  static const String defaultLocale = 'en_US';
}
