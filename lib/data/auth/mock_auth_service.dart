import 'auth_service.dart';

/// Mock auth: starts already "signed in" as a fixed local user so mock mode
/// skips the sign-in screen and behaves exactly as before any auth existed.
/// Matches the previous hardcoded `MockActivityRepository.currentUserId`.
class MockAuthService extends AuthService {
  static const String mockUserId = 'user-rares';

  bool _signedIn = true;
  final Map<String, _MockEmailAccount> _emailAccounts = {};
  String? _activeEmail;
  int _nextEmailId = 0;
  VerificationEmailStatus _verificationEmailStatus =
      VerificationEmailStatus.notSent;

  _MockEmailAccount? get _activeAccount => _emailAccounts[_activeEmail];

  @override
  String? get currentUserId => !_signedIn || isEmailVerificationPending
      ? null
      : _activeAccount?.id ?? mockUserId;

  @override
  String? get displayName =>
      !_signedIn ? null : _activeAccount?.name ?? 'Rares';

  @override
  String? get photoUrl => null;

  @override
  String? get emailAddress => _activeEmail;

  @override
  bool get isEmailVerificationPending =>
      _signedIn && _activeAccount != null && !_activeAccount!.verified;

  @override
  VerificationEmailStatus get verificationEmailStatus =>
      _verificationEmailStatus;

  @override
  bool get emailActionsAreSimulated => true;

  @override
  bool get requiresPasswordForDeletion => _signedIn && _activeAccount != null;

  @override
  Future<void> signInWithGoogle() async {
    _activeEmail = null;
    _signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> signInWithApple() => signInWithGoogle();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _emailAccounts[normalizedEmail];
    if (account == null || account.password != password) {
      throw const EmailAuthException(EmailAuthFailure.invalidCredentials);
    }
    _activeEmail = normalizedEmail;
    _verificationEmailStatus = VerificationEmailStatus.notSent;
    _signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_emailAccounts.containsKey(normalizedEmail)) {
      throw const EmailAuthException(EmailAuthFailure.emailInUse);
    }
    if (password.length < 6) {
      throw const EmailAuthException(EmailAuthFailure.weakPassword);
    }
    _emailAccounts[normalizedEmail] = _MockEmailAccount(
      id: 'mock-email-${++_nextEmailId}',
      name: name.trim(),
      password: password,
    );
    _activeEmail = normalizedEmail;
    _verificationEmailStatus = VerificationEmailStatus.sent;
    _signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {
    if (_activeAccount == null) {
      throw const EmailAuthException(EmailAuthFailure.sessionExpired);
    }
    _verificationEmailStatus = VerificationEmailStatus.sent;
    notifyListeners();
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final account = _activeAccount;
    if (account == null) {
      throw const EmailAuthException(EmailAuthFailure.sessionExpired);
    }
    account.verified = true;
    notifyListeners();
    return true;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    if (_activeAccount?.password != password) {
      throw const EmailAuthException(EmailAuthFailure.invalidCredentials);
    }
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _activeEmail = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() async {
    if (_activeEmail != null) _emailAccounts.remove(_activeEmail);
    _signedIn = false;
    _activeEmail = null;
    notifyListeners();
  }
}

class _MockEmailAccount {
  _MockEmailAccount({
    required this.id,
    required this.name,
    required this.password,
  });

  final String id;
  final String name;
  final String password;
  bool verified = false;
}
