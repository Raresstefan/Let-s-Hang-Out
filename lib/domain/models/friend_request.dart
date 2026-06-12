/// The friendship between two users, from the current user's perspective. Drives
/// the action button on a profile (Add / Requested / Accept / Friends).
enum FriendshipStatus {
  /// No relationship — show "Add friend".
  none,

  /// The current user sent a request that's still pending — show "Requested".
  requestedByMe,

  /// The other user sent the current user a request — show "Accept".
  incoming,

  /// Already friends — show "Friends ✓".
  friends,
}

/// A pending (or resolved) friend request between two users.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String fromId;
  final String toId;

  /// 'pending' | 'accepted' | 'declined'.
  final String status;
  final DateTime? createdAt;
}
