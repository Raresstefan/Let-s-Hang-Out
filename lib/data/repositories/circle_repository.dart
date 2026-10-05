import '../../domain/models/circle.dart';

/// Circles: small recurring groups of friends with a persistent chat. Membership
/// is consensual (invite + accept), mirroring friend requests. The persistent
/// chat reuses the generic chat layer at `chats/{circleId}`.
abstract class CircleRepository {
  /// Creates a circle ([creatorId] is the sole initial member) and its
  /// persistent chat. Returns the created circle.
  Future<Circle> createCircle({
    required String name,
    String? emoji,
    required String creatorId,
  });

  /// Live stream of circles [uid] belongs to.
  Stream<List<Circle>> myCircles(String uid);

  Future<Circle?> fetchCircle(String id);

  /// Sends a pending invite to [toId] to join [circle] (no-op if already a
  /// member or a pending invite exists).
  Future<void> invite({
    required Circle circle,
    required String fromId,
    required String toId,
  });

  /// Accepts [invite]: adds the invitee to the circle's `memberIds` and the
  /// circle chat.
  Future<void> acceptInvite(CircleInvite invite);

  Future<void> declineInvite(CircleInvite invite);
  Future<void> cancelInvite(CircleInvite invite);

  /// Live pending invites sent TO [uid] (badge + list).
  Stream<List<CircleInvite>> incomingInvites(String uid);

  /// Pending invites for a given [circleId] (the circle's "pending" list).
  Future<List<CircleInvite>> outgoingInvitesFor(String circleId);

  /// Removes [uid] from the circle's members. A no-op-safe call: if [uid]
  /// isn't currently a member, the circle is left unchanged. Used when a
  /// member leaves — including a non-creator member deleting their account. A
  /// creator is never removed this way; their circle is left intact.
  Future<void> leaveCircle(String circleId, String uid);
}
