import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/circle.dart';
import 'chat_repository.dart';
import 'circle_repository.dart';

/// Firestore-backed circles.
///
/// Layout:
///   circles/{circleId}        — { name, emoji, creatorId, memberIds, createdAt }
///   circle_invites/{inviteId} — { circleId, circleName, fromId, toId, status, createdAt }
///   chats/{circleId}          — the persistent circle chat (generic chat layer)
///
/// Accept adds the invitee to the circle's memberIds via a field-scoped
/// arrayUnion of their OWN uid (rules permit this, mirroring friendIds), and to
/// the chat's memberIds.
class FirestoreCircleRepository implements CircleRepository {
  FirestoreCircleRepository(this._chats, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final ChatRepository _chats;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _circles =>
      _db.collection('circles');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('circle_invites');

  @override
  Future<Circle> createCircle({
    required String name,
    String? emoji,
    required String creatorId,
  }) async {
    final id = _uuid.v4();
    final circle = Circle(
      id: id,
      name: name,
      emoji: (emoji == null || emoji.isEmpty) ? '👥' : emoji,
      creatorId: creatorId,
      memberIds: [creatorId],
    );
    await _circles.doc(id).set({
      'name': circle.name,
      'emoji': circle.emoji,
      'creatorId': circle.creatorId,
      'memberIds': circle.memberIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Persistent circle chat (reuses the generic chat layer keyed by circleId).
    await _chats.ensureChat(id, title: name, memberIds: [creatorId]);
    return circle;
  }

  @override
  Stream<List<Circle>> myCircles(String uid) {
    return _circles
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((q) => q.docs.map(_fromDoc).toList());
  }

  @override
  Future<Circle?> fetchCircle(String id) async {
    final snap = await _circles.doc(id).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  @override
  Future<void> invite({
    required Circle circle,
    required String fromId,
    required String toId,
  }) async {
    if (toId.isEmpty || toId == fromId || circle.memberIds.contains(toId)) {
      return;
    }
    // Deterministic id (`{circleId}_{toId}`) — the rules verify it before
    // letting the invitee add themselves to the circle. Skip if a pending
    // invite already exists; clear a stale non-pending one.
    final doc = _invites.doc(inviteId(circle.id, toId));
    final existing = await doc.get();
    if (existing.exists) {
      if (existing.data()?['status'] == 'pending') return;
      await doc.delete();
    }
    await doc.set({
      'circleId': circle.id,
      'circleName': circle.name,
      'fromId': fromId,
      'toId': toId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> acceptInvite(CircleInvite invite) async {
    await _invites.doc(invite.id).update({'status': 'accepted'});
    // Field-scoped self-append to the circle members (rules permit own uid).
    await _circles.doc(invite.circleId).set({
      'memberIds': FieldValue.arrayUnion([invite.toId]),
    }, SetOptions(merge: true));
    // Join the persistent circle chat.
    await _chats.addMember(invite.circleId, invite.toId);
    // Handshake done; remove it so a future re-invite can be created fresh.
    await _invites.doc(invite.id).delete();
  }

  /// `circle_invites/{circleId}_{toId}` — the rules rely on this shape.
  static String inviteId(String circleId, String toId) => '${circleId}_$toId';

  @override
  Future<void> declineInvite(CircleInvite invite) async {
    await _invites.doc(invite.id).delete();
  }

  @override
  Future<void> cancelInvite(CircleInvite invite) async {
    await _invites.doc(invite.id).delete();
  }

  @override
  Stream<List<CircleInvite>> incomingInvites(String uid) {
    // Single-field query; 'pending' filtered client-side (no composite index).
    return _invites
        .where('toId', isEqualTo: uid)
        .snapshots()
        .map(
          (q) => q.docs
              .map(_inviteFromDoc)
              .where((i) => i.status == 'pending')
              .toList(),
        );
  }

  @override
  Future<List<CircleInvite>> outgoingInvitesFor(String circleId) async {
    final snap = await _invites.where('circleId', isEqualTo: circleId).get();
    return snap.docs
        .map(_inviteFromDoc)
        .where((i) => i.status == 'pending')
        .toList();
  }

  @override
  Future<void> leaveCircle(String circleId, String uid) async {
    await _circles.doc(circleId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
  }

  Circle _fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const {};
    return Circle(
      id: snap.id,
      name: data['name'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '👥',
      creatorId: data['creatorId'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  CircleInvite _inviteFromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const {};
    return CircleInvite(
      id: snap.id,
      circleId: data['circleId'] as String? ?? '',
      circleName: data['circleName'] as String? ?? '',
      fromId: data['fromId'] as String? ?? '',
      toId: data['toId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
