import 'activity_category.dart';

/// A socialising activity created by a host that other users can join.
class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.placeSuggestion,
    required this.startAt,
    required this.hostId,
    required this.category,
    this.coverImageUrl,
    this.memberIds = const [],
    this.likedBy = const [],
    this.isSuggested = false,
    this.circleId,
    this.ratings = const {},
  });

  final String id;
  final String title;
  final String description;
  final String placeSuggestion;
  final DateTime startAt;
  final String hostId;
  final ActivityCategory category;
  final String? coverImageUrl;

  /// All enrolled users including the host.
  final List<String> memberIds;

  /// Users who liked this activity. The like count is derived from its length.
  final List<String> likedBy;

  final bool isSuggested;

  /// When set, this activity was spun up from a circle and links back to it.
  final String? circleId;

  /// Per-user post-hang ratings (uid → 1–5). A user present here has completed
  /// their recap, so we stop prompting them.
  final Map<String, int> ratings;

  int get enrolledCount => memberIds.length;

  /// Whether [userId] has already rated/recapped this activity.
  bool isRatedBy(String userId) => ratings.containsKey(userId);

  /// Number of likes — derived from [likedBy] (single source of truth).
  int get likeCount => likedBy.length;

  bool isMember(String userId) => memberIds.contains(userId);

  bool isLikedBy(String userId) => likedBy.contains(userId);

  Activity copyWith({
    List<String>? memberIds,
    List<String>? likedBy,
    Map<String, int>? ratings,
  }) =>
      Activity(
        id: id,
        title: title,
        description: description,
        placeSuggestion: placeSuggestion,
        startAt: startAt,
        hostId: hostId,
        category: category,
        coverImageUrl: coverImageUrl,
        memberIds: memberIds ?? this.memberIds,
        likedBy: likedBy ?? this.likedBy,
        isSuggested: isSuggested,
        circleId: circleId,
        ratings: ratings ?? this.ratings,
      );
}
