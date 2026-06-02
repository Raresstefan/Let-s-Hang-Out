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
    this.likeCount = 0,
    this.isSuggested = false,
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

  /// Used by the recommendation/"people liked this" surface.
  final int likeCount;
  final bool isSuggested;

  int get enrolledCount => memberIds.length;

  bool isMember(String userId) => memberIds.contains(userId);

  Activity copyWith({
    List<String>? memberIds,
    int? likeCount,
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
        likeCount: likeCount ?? this.likeCount,
        isSuggested: isSuggested,
      );
}
