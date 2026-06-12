import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import '../../domain/models/host_stats.dart';
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
    // Order by startAt only — no `where('category')` so we avoid a composite
    // index (category + startAt). Category is filtered client-side below; the
    // Discover feed is small enough that this is cheap.
    final snap = await _col.orderBy('startAt').get();
    // Also exclude circle hangouts (circleId set) — they're private to their
    // circle. Filtered client-side so legacy docs (no circleId field) pass.
    return snap.docs.map(_fromDoc).where((a) {
      if (a.circleId != null) return false;
      if (category != null && a.category != category) return false;
      return true;
    }).toList();
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
    // Seed members with the host plus any pre-filled members (e.g. a circle's
    // members when spinning up a hangout), host first and de-duplicated.
    final members = <String>{
      activity.hostId,
      ...activity.memberIds,
    }.toList();
    final created = Activity(
      id: id,
      title: activity.title,
      description: activity.description,
      placeSuggestion: activity.placeSuggestion,
      startAt: activity.startAt,
      hostId: activity.hostId,
      category: activity.category,
      coverImageUrl: activity.coverImageUrl,
      memberIds: members,
      circleId: activity.circleId,
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

  @override
  Future<Activity> rateActivity(
      String activityId, String userId, int rating) async {
    final doc = _col.doc(activityId);
    // Field-merge a single map entry: ratings.{uid} = rating.
    await doc.set({
      'ratings': {userId: rating},
    }, SetOptions(merge: true));
    final snap = await doc.get();
    return _fromDoc(snap);
  }

  @override
  Future<HostStats> hostStats(String hostId) async {
    if (hostId.isEmpty) return const HostStats();
    final snap = await _col.where('hostId', isEqualTo: hostId).get();
    final hosted = snap.docs.map(_fromDoc).toList();
    var sum = 0;
    var count = 0;
    for (final a in hosted) {
      for (final r in a.ratings.values) {
        sum += r;
        count++;
      }
    }
    return HostStats(
      averageRating: count == 0 ? 0 : sum / count,
      ratingCount: count,
      hostedCount: hosted.length,
    );
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
        'circleId': a.circleId,
        'ratings': a.ratings,
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
      circleId: data['circleId'] as String?,
      ratings: _readRatings(data),
    );
  }

  Map<String, int> _readRatings(Map<String, dynamic> data) {
    final raw = data['ratings'] as Map?;
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
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
