import 'package:flutter/foundation.dart';

/// Provides the current user's identity (uid + Google profile) and drives the
/// signed-in/out state the app gates on.
///
/// Abstracts auth so the app never depends on Firebase directly — mock mode
/// starts pre-signed-in as a fixed user, Firebase mode signs in with Google.
/// A [ChangeNotifier] so the auth gate ([app.dart]) can rebuild between the
/// sign-in screen and the home shell.
abstract class AuthService extends ChangeNotifier {
  /// The signed-in user's id, or null if signed out.
  String? get currentUserId;

  /// The signed-in user's display name (Google account name), if any.
  String? get displayName;

  /// The signed-in user's avatar URL (Google photo), if any.
  String? get photoUrl;

  bool get isSignedIn => currentUserId != null;

  /// Launches the Google sign-in flow. Throws on failure (caller shows the
  /// error); a user-cancelled flow completes without signing in.
  Future<void> signInWithGoogle();

  /// Signs out of both Google and Firebase.
  Future<void> signOut();

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
