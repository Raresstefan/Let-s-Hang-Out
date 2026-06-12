import 'package:uuid/uuid.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import '../../domain/models/host_stats.dart';
import 'activity_repository.dart';

/// In-memory implementation seeded with sample data so the app is usable and
/// the feed looks alive without any backend.
class MockActivityRepository implements ActivityRepository {
  MockActivityRepository() {
    _seed();
  }

  final _uuid = const Uuid();
  final List<Activity> _activities = [];

  /// Stand-in for the signed-in user in mock mode.
  static const currentUserId = 'user-rares';

  /// Placeholder liker ids so a seeded count of [n] renders without real users.
  static List<String> _seedLikers(int n) =>
      List.generate(n, (i) => 'seed-user-$i');

  void _seed() {
    final now = DateTime.now();
    _activities.addAll([
      Activity(
        id: 'act-beers',
        title: 'Beers after work 🍺',
        description:
            'Casual drinks downtown. Looking for a few people to unwind with.',
        placeSuggestion: 'The Tap House, Main St.',
        startAt: now.add(const Duration(hours: 6)),
        hostId: 'user-mihai',
        category: ActivityCategory.drinks,
        coverImageUrl:
            'https://images.unsplash.com/photo-1436076863939-06870fe779c2?w=800',
        memberIds: ['user-mihai', 'user-ana'],
        likedBy: _seedLikers(24),
        isSuggested: true,
      ),
      Activity(
        id: 'act-tennis',
        title: 'Tennis match — 2 hours 🎾',
        description: 'Looking for one player. Intermediate level. Bring rackets!',
        placeSuggestion: 'City Sports Park, Court 3',
        startAt: now.add(const Duration(days: 1, hours: 2)),
        hostId: 'user-radu',
        category: ActivityCategory.tennis,
        coverImageUrl:
            'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=800',
        memberIds: ['user-radu'],
        likedBy: _seedLikers(8),
      ),
      Activity(
        id: 'act-coffee',
        title: 'Morning coffee & chat ☕',
        description: 'Slow Saturday coffee, talk about books and travel.',
        placeSuggestion: 'Blue Bottle, Old Town',
        startAt: now.add(const Duration(days: 2, hours: 3)),
        hostId: 'user-ana',
        category: ActivityCategory.coffee,
        coverImageUrl:
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
        memberIds: ['user-ana', 'user-mihai', 'user-radu'],
        likedBy: _seedLikers(41),
        isSuggested: true,
      ),
      Activity(
        id: 'act-food',
        title: 'Street food tour 🍔',
        description: 'Hitting 4 food trucks. Come hungry.',
        placeSuggestion: 'Riverside Market',
        startAt: now.add(const Duration(days: 3)),
        hostId: 'user-mihai',
        category: ActivityCategory.food,
        coverImageUrl:
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800',
        memberIds: ['user-mihai'],
        likedBy: _seedLikers(15),
      ),
    ]);
  }

  @override
  Future<List<Activity>> fetchActivities({ActivityCategory? category}) async {
    await _latency();
    // Circle hangouts (circleId set) are private — excluded from Discover.
    final visible = _activities.where((a) => a.circleId == null);
    final list = category == null
        ? visible.toList()
        : visible.where((a) => a.category == category).toList();
    // Newest start first as a simple ordering.
    final sorted = [...list]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return sorted;
  }

  @override
  Future<List<Activity>> fetchMyActivities(String userId) async {
    await _latency();
    return _activities.where((a) => a.isMember(userId)).toList();
  }

  @override
  Future<Activity> createActivity(Activity activity) async {
    await _latency();
    final members = <String>{activity.hostId, ...activity.memberIds}.toList();
    final created = Activity(
      id: _uuid.v4(),
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
    _activities.insert(0, created);
    return created;
  }

  @override
  Future<Activity> join(String activityId, String userId) async {
    await _latency();
    final idx = _activities.indexWhere((a) => a.id == activityId);
    if (idx == -1) throw StateError('Activity not found: $activityId');
    final activity = _activities[idx];
    if (!activity.isMember(userId)) {
      final updated =
          activity.copyWith(memberIds: [...activity.memberIds, userId]);
      _activities[idx] = updated;
      return updated;
    }
    return activity;
  }

  @override
  Future<Activity> toggleLike(String activityId, String userId) async {
    await _latency();
    final idx = _activities.indexWhere((a) => a.id == activityId);
    if (idx == -1) throw StateError('Activity not found: $activityId');
    final activity = _activities[idx];
    final likedBy = activity.isLikedBy(userId)
        ? activity.likedBy.where((id) => id != userId).toList()
        : [...activity.likedBy, userId];
    final updated = activity.copyWith(likedBy: likedBy);
    _activities[idx] = updated;
    return updated;
  }

  @override
  Future<Activity> rateActivity(
      String activityId, String userId, int rating) async {
    await _latency();
    final idx = _activities.indexWhere((a) => a.id == activityId);
    if (idx == -1) throw StateError('Activity not found: $activityId');
    final activity = _activities[idx];
    final updated = activity.copyWith(
      ratings: {...activity.ratings, userId: rating},
    );
    _activities[idx] = updated;
    return updated;
  }

  @override
  Future<HostStats> hostStats(String hostId) async {
    await _latency();
    final hosted = _activities.where((a) => a.hostId == hostId).toList();
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

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
