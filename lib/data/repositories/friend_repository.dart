import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';

/// The social graph: friend requests + the resulting mutual friendships.
///
/// Friendship is stored denormalized as a mutual `friendIds` array on each
/// user's `users/{uid}` doc (written on accept); the pending handshake lives in
/// a `friend_requests` collection. Person discovery is name-prefix search over
/// the users collection plus adding people you meet via an activity profile.
abstract class FriendRepository {
  /// Sends a pending request from [fromId] to [toId] (no-op if one already
  /// exists in either direction or they're already friends).
  Future<void> sendRequest({required String fromId, required String toId});

  /// Accepts [req]: marks it accepted and adds each user to the other's
  /// `friendIds`.
  Future<void> acceptRequest(FriendRequest req);

  /// Removes the mutual friendship between [me] and [other] (each is removed
  /// from the other's `friendIds`).
  Future<void> unfriend({required String me, required String other});

  /// Declines an incoming [req] (recipient action).
  Future<void> declineRequest(FriendRequest req);

  /// Cancels an outgoing [req] (sender action).
  Future<void> cancelRequest(FriendRequest req);

  /// Live stream of pending requests sent TO [uid] (drives the nav badge).
  Stream<List<FriendRequest>> incomingRequests(String uid);

  /// Pending requests sent BY [uid] (the "Pending" section).
  Future<List<FriendRequest>> outgoingRequests(String uid);

  /// The relationship of [other] relative to [me] (drives the profile button).
  Future<FriendshipStatus> statusBetween(String me, String other);

  /// Name-prefix search over user profiles, excluding [excludeId] (the
  /// searcher). Case-insensitive; bounded by [limit].
  Future<List<AppUser>> searchByName(
    String query, {
    required String excludeId,
    int limit,
  });
}
