import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/user_repository.dart';
import 'auth_service.dart';

/// Real auth via Firebase + Google Sign-In.
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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn.instance,
        _users = userRepository {
    _authSub = _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  // Optional: when provided, the signed-in user's profile is mirrored to the
  // users collection so other members can see their real name + photo.
  final UserRepository? _users;

  User? _user;
  bool _googleInitialized = false;

  late final dynamic _authSub;

  @override
  String? get currentUserId => _user?.uid;

  @override
  String? get displayName => _user?.displayName;

  @override
  String? get photoUrl => _user?.photoURL;

  @override
  Future<void> signInWithGoogle() async {
    if (!_googleInitialized) {
      await _google.initialize();
      _googleInitialized = true;
    }

    // Launches the interactive Google flow. Throws GoogleSignInException with
    // code `canceled` if the user backs out — callers may treat that as a no-op.
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
    // _user is updated via the authStateChanges listener.

    // Mirror identity (name + photo) so other members can render this user's
    // real name + photo. Identity-only — must NOT touch the user's saved bio /
    // interests. Best-effort: a failed write must not block a successful sign-in.
    final user = _auth.currentUser;
    if (_users != null && user != null) {
      try {
        await _users.upsertIdentity(
          user.uid,
          displayName: user.displayName ?? '',
          avatarUrl: user.photoURL,
        );
      } catch (_) {
        // Ignore — identity syncs again on the next sign-in.
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
