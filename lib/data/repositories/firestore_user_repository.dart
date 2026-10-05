import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/app_user.dart';
import 'user_repository.dart';

/// Firestore-backed user profiles, stored at `users/{uid}` with `displayName`,
/// `avatarUrl` and an `updatedAt` server timestamp. Written on sign-in so that
/// other members can see a participant's real name + photo (the activity docs
/// only hold uids).
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Firestore `whereIn` accepts at most 30 values per query; chunk to stay safe.
  static const int _whereInLimit = 30;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  @override
  Future<void> upsertIdentity(
    String id, {
    required String displayName,
    String? avatarUrl,
  }) async {
    // Identity-only write (sign-in). merge:true preserves any saved bio +
    // interests so logging in never wipes the user's edited profile.
    await _col.doc(id).set({
      'displayName': displayName,
      // Lowercased name powers case-insensitive prefix search (friend finder).
      'displayNameLower': displayName.toLowerCase(),
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> upsertProfile(AppUser user) async {
    await _col.doc(user.id).set({
      'displayName': user.displayName,
      'displayNameLower': user.displayName.toLowerCase(),
      'avatarUrl': user.avatarUrl,
      'bio': user.bio,
      'interests': user.interests,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<AppUser?> fetchProfile(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  @override
  Future<List<AppUser>> fetchProfiles(List<String> ids) async {
    final unique = ids.toSet().where((id) => id.isNotEmpty).toList();
    if (unique.isEmpty) return const [];

    final results = <AppUser>[];
    for (var i = 0; i < unique.length; i += _whereInLimit) {
      final chunk = unique.sublist(
        i,
        i + _whereInLimit > unique.length ? unique.length : i + _whereInLimit,
      );
      final snap = await _col.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map(_fromDoc));
    }
    return results;
  }

  @override
  Future<int> acceptedTermsVersion(String id) async {
    final snap = await _col.doc(id).get();
    return (snap.data()?['termsVersion'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> acceptTerms(String id, int version) async {
    await _col.doc(id).set({
      'termsVersion': version,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteProfile(String id) async {
    await _col.doc(id).delete();
  }

  AppUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const {};
    return AppUser(
      id: snap.id,
      displayName: data['displayName'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String? ?? '',
      interests: List<String>.from(data['interests'] as List? ?? const []),
      friendIds: List<String>.from(data['friendIds'] as List? ?? const []),
    );
  }
}
