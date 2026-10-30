import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../repositories/user_repository.dart';
import 'auth_service.dart';

/// Real auth via Firebase, email/password, Google, and Sign in with Apple.
///
/// Uses google_sign_in 7.x: `GoogleSignIn.instance.initialize()` once, then
/// `authenticate()` to get an account whose id token is exchanged for a Firebase
/// credential. Listens to Firebase `authStateChanges()` so the auth gate rebuilds
/// when the user signs in or out (including session restore on relaunch).
class FirebaseAuthService extends AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserRepository? userRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _google = googleSignIn ?? GoogleSignIn.instance,
       _users = userRepository {
    _authSub = _auth.authStateChanges().listen(_onAuthState);
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  // Optional: when provided, the signed-in user's profile is mirrored to the
  // users collection so other members can see their real name + photo.
  final UserRepository? _users;

  User? _user;
  bool _googleInitialized = false;
  bool _emailSignUpInProgress = false;
  bool _verifiedPasswordToken = false;
  bool _checkingPasswordToken = false;
  bool _emailVerificationRefreshFailed = false;
  bool _emailDisplayNameSaveFailed = false;
  bool _disposed = false;
  int _authGeneration = 0;
  VerificationEmailStatus _verificationEmailStatus =
      VerificationEmailStatus.notSent;
  // Apple authorization code captured by [prepareAccountDeletion], used to
  // revoke the Sign in with Apple token right before the account is deleted.
  String? _appleAuthCodeForRevocation;

  late final StreamSubscription<User?> _authSub;

  @override
  String? get currentUserId => isEmailVerificationPending ? null : _user?.uid;

  @override
  String? get displayName => _user?.displayName;

  @override
  String? get photoUrl => _user?.photoURL;

  @override
  String? get emailAddress => _user?.email;

  @override
  bool get isEmailVerificationPending =>
      _hasProvider(_user, _passwordProviderId) &&
      (!_user!.emailVerified || !_verifiedPasswordToken);

  @override
  VerificationEmailStatus get verificationEmailStatus =>
      _verificationEmailStatus;

  @override
  bool get emailDisplayNameSaveFailed => _emailDisplayNameSaveFailed;

  @override
  bool get emailVerificationRefreshFailed => _emailVerificationRefreshFailed;

  @override
  bool get requiresPasswordForDeletion =>
      _hasProvider(_auth.currentUser, _passwordProviderId) &&
      (_emulator || !_hasProvider(_auth.currentUser, _appleProviderId));

  static const bool _emulator = kDebugMode && AppConfig.useFirebaseEmulators;

  void _onAuthState(User? user) {
    if (_emailSignUpInProgress || _disposed) return;
    if (user?.uid != _user?.uid) {
      _authGeneration++;
      _verificationEmailStatus = VerificationEmailStatus.notSent;
      _emailDisplayNameSaveFailed = false;
      _emailVerificationRefreshFailed = false;
      _verifiedPasswordToken = false;
      _checkingPasswordToken = false;
    }
    _user = user;
    notifyListeners();
    if (user != null &&
        _hasProvider(user, _passwordProviderId) &&
        user.emailVerified &&
        !_verifiedPasswordToken &&
        !_checkingPasswordToken) {
      _checkingPasswordToken = true;
      unawaited(_confirmPasswordSession(user, _authGeneration));
    }
  }

  bool _isCurrentSession(User user, int generation) =>
      !_disposed &&
      _authGeneration == generation &&
      _user?.uid == user.uid &&
      _auth.currentUser?.uid == user.uid;

  Future<void> _confirmPasswordSession(User user, int generation) async {
    try {
      var token = await user.getIdTokenResult();
      if (token.claims?['email_verified'] != true) {
        token = await user.getIdTokenResult(true);
      }
      if (token.claims?['email_verified'] != true) {
        throw const EmailAuthException(EmailAuthFailure.unknown);
      }
      if (!_isCurrentSession(user, generation) || !user.emailVerified) return;
      await _mirrorIdentity();
      if (!_isCurrentSession(user, generation) || !user.emailVerified) return;
      _verifiedPasswordToken = true;
      _emailVerificationRefreshFailed = false;
    } catch (e) {
      if (!_isCurrentSession(user, generation)) return;
      debugPrint(
        'Could not confirm the verified email token: ${e.runtimeType}',
      );
      _emailVerificationRefreshFailed = true;
    } finally {
      if (_isCurrentSession(user, generation)) {
        _checkingPasswordToken = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    if (_emulator) {
      // The Auth emulator accepts an unsigned JSON id token.
      const email = AppConfig.emulatorUserEmail;
      final name = email.split('@').first;
      await _signInWithGoogleCredential(
        GoogleAuthProvider.credential(
          idToken: jsonEncode({
            'sub': name,
            'email': email,
            'email_verified': true,
            'name': name[0].toUpperCase() + name.substring(1),
          }),
        ),
      );
      await _mirrorIdentity();
      return;
    }
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }

    // Launches the interactive Google flow. Throws GoogleSignInException with
    // code `canceled` if the user backs out — callers may treat that as a no-op.
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _signInWithGoogleCredential(credential);
    // _user is updated via the authStateChanges listener.

    await _mirrorIdentity();
  }

  Future<void> _signInWithGoogleCredential(AuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw const AccountExistsWithOtherProvider.unknown();
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _verificationEmailStatus = VerificationEmailStatus.notSent;
    _emailDisplayNameSaveFailed = false;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _emailException(e);
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _emailSignUpInProgress = true;
    _verificationEmailStatus = VerificationEmailStatus.notSent;
    _emailDisplayNameSaveFailed = false;
    _verifiedPasswordToken = false;
    _emailVerificationRefreshFailed = false;
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const EmailAuthException(EmailAuthFailure.sessionExpired);
      }
      try {
        await user.updateDisplayName(name.trim());
      } on FirebaseAuthException catch (e) {
        _emailDisplayNameSaveFailed = true;
        debugPrint('Could not save the email account name: ${e.code}');
      } on PlatformException catch (e) {
        _emailDisplayNameSaveFailed = true;
        debugPrint('Could not save the email account name: ${e.code}');
      }
      try {
        await user.sendEmailVerification();
        _verificationEmailStatus = VerificationEmailStatus.sent;
      } on FirebaseAuthException catch (e) {
        _verificationEmailStatus = VerificationEmailStatus.failed;
        debugPrint('Could not send the verification email: ${e.code}');
      } on PlatformException catch (e) {
        _verificationEmailStatus = VerificationEmailStatus.failed;
        debugPrint('Could not send the verification email: ${e.code}');
      }
    } on FirebaseAuthException catch (e) {
      throw _emailException(e);
    } finally {
      _emailSignUpInProgress = false;
      _authGeneration++;
      _checkingPasswordToken = false;
      _user = _auth.currentUser;
      notifyListeners();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // The confirmation is intentionally identical for unknown accounts.
      if (e.code == 'user-not-found') return;
      throw _emailException(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailAuthException(EmailAuthFailure.sessionExpired);
    }
    try {
      await user.sendEmailVerification();
      _verificationEmailStatus = VerificationEmailStatus.sent;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _verificationEmailStatus = VerificationEmailStatus.failed;
      notifyListeners();
      throw _emailException(e);
    }
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailAuthException(EmailAuthFailure.sessionExpired);
    }
    final generation = ++_authGeneration;
    _checkingPasswordToken = true;
    _verifiedPasswordToken = false;
    _emailVerificationRefreshFailed = false;
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null) {
        throw const EmailAuthException(EmailAuthFailure.sessionExpired);
      }
      if (!refreshed.emailVerified) {
        return false;
      }
      final token = await refreshed.getIdTokenResult(true);
      if (token.claims?['email_verified'] != true) {
        throw const EmailAuthException(EmailAuthFailure.unknown);
      }
      if (!_isCurrentSession(user, generation)) {
        throw const EmailAuthException(EmailAuthFailure.sessionExpired);
      }
      await _mirrorIdentity();
      if (!_isCurrentSession(user, generation)) {
        throw const EmailAuthException(EmailAuthFailure.sessionExpired);
      }
      _verifiedPasswordToken = true;
      return true;
    } on FirebaseAuthException catch (e) {
      if (_isCurrentSession(user, generation)) {
        _emailVerificationRefreshFailed = true;
      }
      throw _emailException(e);
    } catch (_) {
      if (_isCurrentSession(user, generation)) {
        _emailVerificationRefreshFailed = true;
      }
      rethrow;
    } finally {
      if (_isCurrentSession(user, generation)) {
        _user = _auth.currentUser;
        _checkingPasswordToken = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const EmailAuthException(EmailAuthFailure.sessionExpired);
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw _emailException(e);
    }
  }

  static EmailAuthException _emailException(FirebaseAuthException error) {
    final reason = switch (error.code) {
      'invalid-email' => EmailAuthFailure.invalidEmail,
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' ||
      'user-mismatch' => EmailAuthFailure.invalidCredentials,
      'email-already-in-use' => EmailAuthFailure.emailInUse,
      'weak-password' => EmailAuthFailure.weakPassword,
      'too-many-requests' => EmailAuthFailure.tooManyRequests,
      'network-request-failed' => EmailAuthFailure.network,
      'user-disabled' => EmailAuthFailure.userDisabled,
      'operation-not-allowed' => EmailAuthFailure.providerDisabled,
      'requires-recent-login' ||
      'user-token-expired' => EmailAuthFailure.sessionExpired,
      _ => EmailAuthFailure.unknown,
    };
    return EmailAuthException(reason);
  }

  @override
  Future<void> signInWithApple() async {
    try {
      if (_emulator) {
        // The Auth emulator accepts an unsigned JSON id token.
        const email = AppConfig.emulatorUserEmail;
        final name = email.split('@').first;
        await _auth.signInWithCredential(
          OAuthProvider('apple.com').credential(
            idToken: jsonEncode({
              'sub': 'apple-$name',
              'email': email,
              'email_verified': true,
            }),
            rawNonce: 'emulator',
          ),
        );
      } else {
        // Native ASAuthorization sheet on iOS. Apple only returns the name on
        // the very first authorization; the plugin passes it to Firebase.
        await _auth.signInWithProvider(
          AppleAuthProvider()
            ..addScope('email')
            ..addScope('name'),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAppleError(e);
    } on PlatformException catch (e) {
      if (isCancelCode(e.code)) throw const SignInCancelled();
      rethrow;
    }
    await _mirrorIdentity();
  }

  static Object _mapAppleError(FirebaseAuthException e) {
    if (isCancelCode(e.code)) return const SignInCancelled();
    if (e.code == 'account-exists-with-different-credential') {
      return const AccountExistsWithOtherProvider.unknown();
    }
    return e;
  }

  @visibleForTesting
  static bool isCancelCode(String code) =>
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-canceled' ||
      code == 'web-context-cancelled';

  /// Only Google users have a google_sign_in session to clear; calling it for
  /// Apple users would needlessly initialize the Google SDK.
  @visibleForTesting
  static bool shouldSignOutOfGoogle(Iterable<String> providerIds) =>
      providerIds.contains('google.com');

  static const _appleProviderId = 'apple.com';
  static const _passwordProviderId = 'password';

  bool _hasProvider(User? user, String providerId) =>
      user?.providerData.any((p) => p.providerId == providerId) ?? false;

  Future<void> _signOutOfGoogleIfNeeded(User? user) async {
    if (_emulator || user == null) return;
    if (!shouldSignOutOfGoogle(user.providerData.map((p) => p.providerId))) {
      return;
    }
    try {
      if (!_googleInitialized) {
        await _google.initialize();
        _googleInitialized = true;
      }
      await _google.signOut();
    } catch (_) {
      // Best-effort: Firebase sign-out below is what actually ends the session.
    }
  }

  // Mirror identity (name + photo) so other members can render this user's
  // real name + photo. Identity-only — must NOT touch the user's saved bio /
  // interests. Best-effort: a failed write must not block a successful sign-in.
  Future<void> _mirrorIdentity() async {
    final user = _auth.currentUser;
    if (_users != null && user != null) {
      try {
        await _users.upsertIdentity(
          user.uid,
          displayName: user.displayName ?? '',
          avatarUrl: user.photoURL,
        );
      } catch (e) {
        debugPrint('Could not sync the signed-in profile: ${e.runtimeType}');
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _signOutOfGoogleIfNeeded(_auth.currentUser);
    await _auth.signOut();
  }

  @override
  Future<void> prepareAccountDeletion() async {
    _appleAuthCodeForRevocation = null;
    final user = _auth.currentUser;
    if (_emulator || !_hasProvider(user, _appleProviderId)) return;
    try {
      // Fresh Apple confirmation: yields an authorization code for token
      // revocation and satisfies Firebase's recent-login requirement.
      final cred = await user!.reauthenticateWithProvider(AppleAuthProvider());
      _appleAuthCodeForRevocation = cred.additionalUserInfo?.authorizationCode;
      if (_appleAuthCodeForRevocation == null) {
        debugPrint('Apple re-auth returned no authorization code.');
      }
    } on FirebaseAuthException catch (e) {
      if (isCancelCode(e.code)) throw const SignInCancelled();
      rethrow;
    } on PlatformException catch (e) {
      if (isCancelCode(e.code)) throw const SignInCancelled();
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final code = _appleAuthCodeForRevocation;
    _appleAuthCodeForRevocation = null;
    if (code != null) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(code);
      } catch (e) {
        // Best-effort: never block deletion on revocation.
        debugPrint('Apple token revocation failed: $e');
      }
    }
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AccountDeletionRequiresRecentLogin();
      }
      rethrow;
    }
    // Deleting the user signs it out under the hood, but authStateChanges()
    // doesn't reliably re-emit promptly on every platform — clear local state
    // directly so the auth gate flips to the sign-in screen immediately
    // instead of appearing to leave the deleted account "still signed in".
    await _signOutOfGoogleIfNeeded(user);
    _onAuthState(null);
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub.cancel();
    super.dispose();
  }
}
