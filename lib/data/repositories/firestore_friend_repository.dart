import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';
import 'friend_repository.dart';

/// Firestore-backed social graph.
///
/// Layout:
///   friend_requests/{requestId}  — { fromId, toId, status, createdAt }
///   users/{uid}.friendIds        — mutual array, written on accept
///
/// Accept writes both sides' `friendIds`: the accepter adds the requester to
/// their OWN doc and appends THEMSELVES to the requester's doc. Both are
/// field-scoped (`friendIds` only, element == own uid), which the security
/// rules permit (mirrors the `likedBy` like/unlike rule on activities).
class FirestoreFriendRepository implements FriendRepository {
  FirestoreFriendRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friend_requests');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<void> sendRequest({
    required String fromId,
    required String toId,
  }) async {
    if (fromId == toId || fromId.isEmpty || toId.isEmpty) return;
    // Guard against duplicates: skip if a pending request exists either way, or
    // if they're already friends.
    if (await statusBetween(fromId, toId) != FriendshipStatus.none) return;
    final id = _uuid.v4();
    await _requests.doc(id).set({
      'fromId': fromId,
      'toId': toId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> acceptRequest(FriendRequest req) async {
    final me = req.toId; // the accepter
    final them = req.fromId;
    await _requests.doc(req.id).update({'status': 'accepted'});
    // Each write is field-scoped to friendIds and only adds the caller's uid.
    await _users.doc(me).set({
      'friendIds': FieldValue.arrayUnion([them]),
    }, SetOptions(merge: true));
    await _users.doc(them).set({
      'friendIds': FieldValue.arrayUnion([me]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unfriend({required String me, required String other}) async {
    // Field-scoped removals: each side removes only the OTHER's uid. Removing
    // `other` from my own doc is a self-write; removing `me` from their doc is
    // the field-scoped cross-user write the rules permit.
    await _users.doc(me).set({
      'friendIds': FieldValue.arrayRemove([other]),
    }, SetOptions(merge: true));
    await _users.doc(other).set({
      'friendIds': FieldValue.arrayRemove([me]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> declineRequest(FriendRequest req) async {
    await _requests.doc(req.id).delete();
  }

  @override
  Future<void> cancelRequest(FriendRequest req) async {
    await _requests.doc(req.id).delete();
  }

  @override
  Stream<List<FriendRequest>> incomingRequests(String uid) {
    // Single-field query (no composite index needed); 'pending' filtered
    // client-side. Avoids a silent index error that would kill the stream.
    return _requests
        .where('toId', isEqualTo: uid)
        .snapshots()
        .map((q) => q.docs
            .map(_fromDoc)
            .where((r) => r.status == 'pending')
            .toList());
  }

  @override
  Future<List<FriendRequest>> outgoingRequests(String uid) async {
    final snap = await _requests.where('fromId', isEqualTo: uid).get();
    return snap.docs
        .map(_fromDoc)
        .where((r) => r.status == 'pending')
        .toList();
  }

  @override
  Future<FriendshipStatus> statusBetween(String me, String other) async {
    if (me.isEmpty || other.isEmpty || me == other) {
      return FriendshipStatus.none;
    }
    // Already friends? Check my own friendIds.
    final meDoc = await _users.doc(me).get();
    final myFriends =
        List<String>.from(meDoc.data()?['friendIds'] as List? ?? const []);
    if (myFriends.contains(other)) return FriendshipStatus.friends;

    // Pending in either direction — derived ONLY from queries scoped to `me`
    // (the rules forbid listing another user's requests). Outgoing: my
    // fromId==me docs to `other`. Incoming: my toId==me docs from `other`.
    final mineOut = await _requests.where('fromId', isEqualTo: me).get();
    if (mineOut.docs.map(_fromDoc).any(
        (r) => r.toId == other && r.status == 'pending')) {
      return FriendshipStatus.requestedByMe;
    }

    final mineIn = await _requests.where('toId', isEqualTo: me).get();
    if (mineIn.docs.map(_fromDoc).any(
        (r) => r.fromId == other && r.status == 'pending')) {
      return FriendshipStatus.incoming;
    }

    return FriendshipStatus.none;
  }

  @override
  Future<List<AppUser>> searchByName(
    String query, {
    required String excludeId,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    // Prefix range query on the lowercased name: [q, q + high sentinel)
    // captures every name starting with q (U+F8FF is a very high code point).
    final snap = await _users
        .where('displayNameLower', isGreaterThanOrEqualTo: q)
        .where('displayNameLower', isLessThan: '$q')
        .limit(limit)
        .get();
    return snap.docs
        .where((d) => d.id != excludeId)
        .map(_userFromDoc)
        .toList();
  }

  FriendRequest _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return FriendRequest(
      id: doc.id,
      fromId: data['fromId'] as String? ?? '',
      toId: data['toId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
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
