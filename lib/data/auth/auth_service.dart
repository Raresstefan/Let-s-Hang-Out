import 'package:flutter/foundation.dart';

/// Provides the current user's identity and drives the app's auth gates.
///
/// Abstracts auth so the app never depends on Firebase directly — mock mode
/// starts pre-signed-in as a fixed user, while Firebase supports the configured
/// sign-in providers.
/// A [ChangeNotifier] so the auth gate ([app.dart]) can rebuild between the
/// sign-in screen and the home shell.
abstract class AuthService extends ChangeNotifier {
  /// The usable user's id, or null while signed out or awaiting verification.
  String? get currentUserId;

  /// The signed-in user's display name, if any.
  String? get displayName;

  /// The signed-in user's avatar URL, if any.
  String? get photoUrl;

  bool get isSignedIn => currentUserId != null;

  /// Launches the Google sign-in flow. Throws on failure (caller shows the
  /// error); a user-cancelled flow completes without signing in.
  Future<void> signInWithGoogle();

  /// Launches the Sign in with Apple flow (iOS). Throws [SignInCancelled] if
  /// the user closes the Apple sheet, [AccountExistsWithOtherProvider] if the
  /// email already belongs to a Google account, or anything else on failure.
  Future<void> signInWithApple();

  /// Whether an email/password account must verify its email before entering.
  bool get isEmailVerificationPending => false;

  String? get emailAddress => null;

  VerificationEmailStatus get verificationEmailStatus =>
      VerificationEmailStatus.notSent;

  bool get emailDisplayNameSaveFailed => false;

  bool get emailVerificationRefreshFailed => false;

  /// Mock mode does not actually deliver account-management emails.
  bool get emailActionsAreSimulated => false;

  bool get requiresPasswordForDeletion => false;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async => throw UnsupportedError('Email sign-in is not supported');

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async => throw UnsupportedError('Email sign-up is not supported');

  Future<void> sendPasswordResetEmail(String email) async =>
      throw UnsupportedError('Password reset is not supported');

  Future<void> sendEmailVerification() async =>
      throw UnsupportedError('Email verification is not supported');

  /// Refreshes the current user and returns whether the email is verified.
  Future<bool> refreshEmailVerification() async =>
      throw UnsupportedError('Email verification is not supported');

  Future<void> reauthenticateWithPassword(String password) async =>
      throw UnsupportedError('Password reauthentication is not supported');

  /// Signs out of Firebase (and Google, for Google users).
  Future<void> signOut();

  /// Runs before any account data is deleted. Apple users confirm with Face ID
  /// here so their Sign in with Apple token can be revoked on deletion
  /// (App Store 5.1.1(v)). Throws [SignInCancelled] if they back out, leaving
  /// the account untouched. A no-op for other providers.
  Future<void> prepareAccountDeletion() async {}

  /// Permanently deletes the signed-in user's account. Callers must delete any
  /// owned data (e.g. the Firestore profile doc) beforehand — this only
  /// removes the auth identity itself, which then flips [isSignedIn] to false.
  ///
  /// Firebase may reject this with [AccountDeletionRequiresRecentLogin] if the
  /// session is too old for a sensitive operation. Callers should sign the
  /// user out and ask them to sign back in and retry — a fresh session then
  /// deletes immediately, with no re-auth prompt mid-flow.
  Future<void> deleteAccount();
}

/// Thrown by [AuthService.deleteAccount] when Firebase requires a fresher
/// sign-in before allowing this sensitive operation. The account is
/// untouched; the caller should sign the user out so their next sign-in
/// establishes a fresh session to retry with.
class AccountDeletionRequiresRecentLogin implements Exception {
  const AccountDeletionRequiresRecentLogin();
}

/// The user closed the sign-in / confirmation sheet. Not an error to show.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// This email is already registered with another sign-in provider.
class AccountExistsWithOtherProvider implements Exception {
  /// The original constructor represents a known Google account.
  const AccountExistsWithOtherProvider() : existingProvider = 'google.com';

  /// Use when Firebase does not reveal the existing provider.
  const AccountExistsWithOtherProvider.unknown() : existingProvider = null;

  final String? existingProvider;
}

enum VerificationEmailStatus { notSent, sent, failed }

enum EmailAuthFailure {
  invalidEmail,
  invalidCredentials,
  emailInUse,
  weakPassword,
  tooManyRequests,
  network,
  userDisabled,
  providerDisabled,
  sessionExpired,
  unknown,
}

class EmailAuthException implements Exception {
  const EmailAuthException(this.reason);

  final EmailAuthFailure reason;
}
