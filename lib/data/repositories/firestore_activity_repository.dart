import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import 'activity_repository.dart';

/// Firestore-backed activities. Mirrors the [Activity] model into
/// `activities/{activityId}`. Seed a few docs via the in-app Create screen or
/// by hand in the Firestore console so the feed isn't empty.
class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('activities');

  @override
  Future<List<Activity>> fetchActivities({ActivityCategory? category}) async {
    Query<Map<String, dynamic>> query = _col.orderBy('startAt');
    if (category != null) {
      query = query.where('category', isEqualTo: category.id);
    }
    final snap = await query.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<Activity>> fetchMyActivities(String userId) async {
    final snap =
        await _col.where('memberIds', arrayContains: userId).get();
    final list = snap.docs.map(_fromDoc).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  @override
  Future<Activity> createActivity(Activity activity) async {
    final id = _uuid.v4();
    final created = Activity(
      id: id,
      title: activity.title,
      description: activity.description,
      placeSuggestion: activity.placeSuggestion,
      startAt: activity.startAt,
      hostId: activity.hostId,
      category: activity.category,
      coverImageUrl: activity.coverImageUrl,
      memberIds: [activity.hostId],
    );
    await _col.doc(id).set(_toMap(created));
    return created;
  }

  @override
  Future<Activity> join(String activityId, String userId) async {
    final doc = _col.doc(activityId);
    await doc.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    final snap = await doc.get();
    return _fromDoc(snap);
  }

  @override
  Future<Activity> toggleLike(String activityId, String userId) async {
    final doc = _col.doc(activityId);
    final current = _fromDoc(await doc.get());
    await doc.update({
      'likedBy': current.isLikedBy(userId)
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
    final snap = await doc.get();
    return _fromDoc(snap);
  }

  Map<String, dynamic> _toMap(Activity a) => {
        'title': a.title,
        'description': a.description,
        'placeSuggestion': a.placeSuggestion,
        'startAt': Timestamp.fromDate(a.startAt),
        'hostId': a.hostId,
        'category': a.category.id,
        'coverImageUrl': a.coverImageUrl,
        'memberIds': a.memberIds,
        'likedBy': a.likedBy,
        'isSuggested': a.isSuggested,
      };

  Activity _fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Activity(
      id: snap.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      placeSuggestion: data['placeSuggestion'] as String? ?? '',
      startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostId: data['hostId'] as String? ?? '',
      category: ActivityCategory.fromId(data['category'] as String? ?? 'drinks'),
      coverImageUrl: data['coverImageUrl'] as String?,
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      likedBy: _readLikedBy(data),
      isSuggested: data['isSuggested'] as bool? ?? false,
    );
  }

  /// Reads the likers list, with back-compat for legacy docs that only have a
  /// numeric `likeCount` (no `likedBy` array): synthesize a placeholder list of
  /// that length so the count still renders before the first toggle.
  List<String> _readLikedBy(Map<String, dynamic> data) {
    final raw = data['likedBy'] as List?;
    if (raw != null) return List<String>.from(raw);
    final legacy = (data['likeCount'] as num?)?.toInt() ?? 0;
    return List.generate(legacy, (i) => 'legacy-like-$i');
  }
}
