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

  /// Default / starting locale. Only en_US is shipped for now.
  static const String defaultLocale = 'en_US';
}
