import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';
import 'friend_repository.dart';
import 'mock_user_repository.dart';

/// In-memory social graph for mock mode. Shares [MockUserRepository]'s profile
/// store so friendIds + name search operate on the same users.
class MockFriendRepository implements FriendRepository {
  MockFriendRepository(this._users);

  final MockUserRepository _users;
  final _uuid = const Uuid();

  final List<FriendRequest> _requests = [];
  final _incoming = <String, StreamController<List<FriendRequest>>>{};

  void _emitIncoming(String uid) {
    _incoming[uid]?.add(_pendingTo(uid));
  }

  List<FriendRequest> _pendingTo(String uid) => _requests
      .where((r) => r.toId == uid && r.status == 'pending')
      .toList();

  @override
  Future<void> sendRequest({
    required String fromId,
    required String toId,
  }) async {
    if (fromId == toId || fromId.isEmpty || toId.isEmpty) return;
    if (await statusBetween(fromId, toId) != FriendshipStatus.none) return;
    _requests.add(FriendRequest(
      id: _uuid.v4(),
      fromId: fromId,
      toId: toId,
      status: 'pending',
      createdAt: DateTime.now(),
    ));
    _emitIncoming(toId);
  }

  @override
  Future<void> acceptRequest(FriendRequest req) async {
    _requests.removeWhere((r) => r.id == req.id);
    _link(req.fromId, req.toId);
    _link(req.toId, req.fromId);
    _emitIncoming(req.toId);
  }

  void _link(String owner, String friend) {
    final existing = _users.profiles[owner] ??
        AppUser(id: owner, displayName: owner);
    if (existing.friendIds.contains(friend)) return;
    _users.profiles[owner] =
        existing.copyWith(friendIds: [...existing.friendIds, friend]);
  }

  void _unlink(String owner, String friend) {
    final existing = _users.profiles[owner];
    if (existing == null || !existing.friendIds.contains(friend)) return;
    _users.profiles[owner] = existing.copyWith(
        friendIds: existing.friendIds.where((id) => id != friend).toList());
  }

  @override
  Future<void> unfriend({required String me, required String other}) async {
    _unlink(me, other);
    _unlink(other, me);
  }

  @override
  Future<void> declineRequest(FriendRequest req) async {
    _requests.removeWhere((r) => r.id == req.id);
    _emitIncoming(req.toId);
  }

  @override
  Future<void> cancelRequest(FriendRequest req) async {
    _requests.removeWhere((r) => r.id == req.id);
    _emitIncoming(req.toId);
  }

  @override
  Stream<List<FriendRequest>> incomingRequests(String uid) {
    final controller = _incoming.putIfAbsent(
        uid, () => StreamController<List<FriendRequest>>.broadcast());
    scheduleMicrotask(() => controller.add(_pendingTo(uid)));
    return controller.stream;
  }

  @override
  Future<List<FriendRequest>> outgoingRequests(String uid) async => _requests
      .where((r) => r.fromId == uid && r.status == 'pending')
      .toList();

  @override
  Future<FriendshipStatus> statusBetween(String me, String other) async {
    if (me.isEmpty || other.isEmpty || me == other) {
      return FriendshipStatus.none;
    }
    final myFriends = _users.profiles[me]?.friendIds ?? const [];
    if (myFriends.contains(other)) return FriendshipStatus.friends;
    final out = _requests.any((r) =>
        r.fromId == me && r.toId == other && r.status == 'pending');
    if (out) return FriendshipStatus.requestedByMe;
    final incoming = _requests.any((r) =>
        r.fromId == other && r.toId == me && r.status == 'pending');
    if (incoming) return FriendshipStatus.incoming;
    return FriendshipStatus.none;
  }

  @override
  Future<List<AppUser>> searchByName(
    String query, {
    required String excludeId,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _users.profiles.values
        .where((u) =>
            u.id != excludeId &&
            u.displayName.toLowerCase().startsWith(q))
        .take(limit)
        .toList();
  }
}
