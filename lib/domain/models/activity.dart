import 'activity_category.dart';
import 'city_names.dart';

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
    this.city = '',
    this.coverImageUrl,
    this.memberIds = const [],
    this.likedBy = const [],
    this.isSuggested = false,
    this.circleId,
    this.ratings = const {},
    this.removedIds = const [],
    this.cancelled = false,
  });

  final String id;
  final String title;
  final String description;
  final String placeSuggestion;
  final DateTime startAt;
  final String hostId;
  final ActivityCategory category;

  /// City the hangout happens in, typed by the host. Empty on activities
  /// created before the field existed; those only show under "All cities".
  final String city;

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

  /// Users the host removed. They can't rejoin and the activity is hidden
  /// from their feed.
  final List<String> removedIds;

  /// The host called it off. Kept (not deleted) so members see "Cancelled"
  /// in their hangouts and chat instead of it silently vanishing.
  final bool cancelled;

  /// "Old City Pub, Amsterdam" — the place plus its city, unless the place
  /// already names the city. Also the query used for map directions.
  String get placeWithCity {
    final place = placeSuggestion.trim();
    final c = city.trim();
    if (c.isEmpty) return place;
    if (place.isEmpty) return c;
    if (cityKey(place).contains(cityKey(c))) return place;
    return '$place, $c';
  }

  bool isRemoved(String userId) => removedIds.contains(userId);

  int get enrolledCount => memberIds.length;

  /// Whether [userId] has already rated/recapped this activity.
  bool isRatedBy(String userId) => ratings.containsKey(userId);

  /// Number of likes — derived from [likedBy] (single source of truth).
  int get likeCount => likedBy.length;

  bool isMember(String userId) => memberIds.contains(userId);

  bool isLikedBy(String userId) => likedBy.contains(userId);

  Activity copyWith({
    String? title,
    String? description,
    String? placeSuggestion,
    String? city,
    DateTime? startAt,
    ActivityCategory? category,
    bool? cancelled,
    List<String>? memberIds,
    List<String>? likedBy,
    Map<String, int>? ratings,
    List<String>? removedIds,
    String? coverImageUrl,
  }) =>
      Activity(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        placeSuggestion: placeSuggestion ?? this.placeSuggestion,
        startAt: startAt ?? this.startAt,
        hostId: hostId,
        category: category ?? this.category,
        city: city ?? this.city,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        memberIds: memberIds ?? this.memberIds,
        likedBy: likedBy ?? this.likedBy,
        isSuggested: isSuggested,
        circleId: circleId,
        ratings: ratings ?? this.ratings,
        removedIds: removedIds ?? this.removedIds,
        cancelled: cancelled ?? this.cancelled,
      );
}
