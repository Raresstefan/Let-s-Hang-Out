/// A user of the app.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.friendIds = const [],
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final List<String> friendIds;

  AppUser copyWith({List<String>? friendIds}) => AppUser(
        id: id,
        displayName: displayName,
        avatarUrl: avatarUrl,
        friendIds: friendIds ?? this.friendIds,
      );
}
