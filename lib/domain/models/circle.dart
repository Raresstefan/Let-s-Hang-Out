/// A small, named, persistent group of friends ("Tuesday Tennis"). Keeps a
/// persistent group chat (at `chats/{id}`) and can spin up activities that link
/// back via `Activity.circleId`.
class Circle {
  const Circle({
    required this.id,
    required this.name,
    this.emoji = '👥',
    required this.creatorId,
    this.memberIds = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final String creatorId;
  final List<String> memberIds;
  final DateTime? createdAt;

  int get memberCount => memberIds.length;
  bool isMember(String uid) => memberIds.contains(uid);
}

/// A pending (or resolved) invitation to join a circle. Mirrors
/// [FriendRequest] — the consensual invite+accept handshake.
class CircleInvite {
  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.fromId,
    required this.toId,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String circleId;
  final String circleName;
  final String fromId;
  final String toId;

  /// 'pending' | 'accepted' | 'declined'.
  final String status;
  final DateTime? createdAt;
}
