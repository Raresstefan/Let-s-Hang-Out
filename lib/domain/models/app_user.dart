/// A user of the app.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
    this.interests = const [],
    this.friendIds = const [],
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  /// Short self-description shown on the profile. Empty when unset.
  final String bio;

  /// Categories the user is into, stored as [ActivityCategory.id] strings
  /// (e.g. 'coffee', 'tennis'). Fuels recommendations + friend-matching later.
  final List<String> interests;

  final List<String> friendIds;

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String>? interests,
    List<String>? friendIds,
  }) =>
      AppUser(
        id: id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        interests: interests ?? this.interests,
        friendIds: friendIds ?? this.friendIds,
      );
}
