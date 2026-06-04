import 'auth_service.dart';

/// Mock auth: starts already "signed in" as a fixed local user so mock mode
/// skips the sign-in screen and behaves exactly as before any auth existed.
/// Matches the previous hardcoded `MockActivityRepository.currentUserId`.
class MockAuthService extends AuthService {
  static const String mockUserId = 'user-rares';

  bool _signedIn = true;

  @override
  String? get currentUserId => _signedIn ? mockUserId : null;

  @override
  String? get displayName => _signedIn ? 'Rares' : null;

  @override
  String? get photoUrl => null;

  @override
  Future<void> signInWithGoogle() async {
    _signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    notifyListeners();
  }
}
