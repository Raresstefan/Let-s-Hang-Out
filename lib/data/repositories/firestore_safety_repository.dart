import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/report.dart';
import 'safety_repository.dart';

/// Layout:
///   blocks/{uid}   — { ids: [blockedUid…] }, readable/writable only by uid
///   reports/{id}   — create-only; reviewed in the Firebase console
class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _blocks(String uid) =>
      _db.collection('blocks').doc(uid);

  @override
  Future<Set<String>> fetchBlocked(String uid) async {
    final snap = await _blocks(uid).get();
    return Set<String>.from(snap.data()?['ids'] as List? ?? const []);
  }

  @override
  Future<void> block({required String me, required String other}) =>
      _blocks(me).set({
        'ids': FieldValue.arrayUnion([other]),
      }, SetOptions(merge: true));

  @override
  Future<void> unblock({required String me, required String other}) =>
      _blocks(me).set({
        'ids': FieldValue.arrayRemove([other]),
      }, SetOptions(merge: true));

  @override
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String details = '',
    String? chatId,
    String? activityId,
  }) =>
      _db.collection('reports').add({
        'reporterId': reporterId,
        'targetType': target.id,
        'targetId': targetId,
        'reason': reason.id,
        'details': details,
        'chatId': ?chatId,
        'activityId': ?activityId,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
}
