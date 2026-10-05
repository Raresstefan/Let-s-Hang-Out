import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/friend_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';
import '../safety/safety_controller.dart';

/// A friend request paired with the other party's resolved profile, for display.
class RequestEntry {
  const RequestEntry(this.request, this.user);
  final FriendRequest request;
  final AppUser user;
}

/// Drives the Friends tab + the friendship action on a profile: the friends
/// list, incoming requests (live, for the nav badge), outgoing/pending, and
/// name search.
class FriendsController extends ChangeNotifier {
  FriendsController({
    required FriendRepository friendRepository,
    required UserRepository userRepository,
    required AuthService authService,
    required AnalyticsService analytics,
    SafetyController? safety,
  })  : _friends = friendRepository,
        _safety = safety,
        _users = userRepository,
        _auth = authService,
        _analytics = analytics {
    // Block/unblock changes the friends list and what's visible.
    _safety?.addListener(load);
    _listenIncoming();
    load();
  }

  final FriendRepository _friends;
  final UserRepository _users;
  final AuthService _auth;
  final AnalyticsService _analytics;
  final SafetyController? _safety;

  bool _visible(String uid) => !(_safety?.isBlocked(uid) ?? false);

  StreamSubscription<List<FriendRequest>>? _incomingSub;

  bool _loading = false;
  bool get loading => _loading;

  List<AppUser> _friendsList = [];
  List<AppUser> get friends => _friendsList;

  List<RequestEntry> _incoming = [];
  List<RequestEntry> get incoming =>
      _incoming.where((e) => _visible(e.request.fromId)).toList();
  int get incomingCount => incoming.length;

  List<RequestEntry> _outgoing = [];
  List<RequestEntry> get outgoing => _outgoing;

  List<AppUser> _searchResults = [];
  List<AppUser> get searchResults =>
      _searchResults.where((u) => _visible(u.id)).toList();
  bool _searching = false;
  bool get searching => _searching;

  String? get _uid => _auth.currentUserId;

  void _listenIncoming() {
    final uid = _uid;
    if (uid == null) return;
    _incomingSub?.cancel();
    _incomingSub = _friends.incomingRequests(uid).listen(
      (reqs) async {
        _incoming = await _withProfiles(reqs, useFrom: true);
        notifyListeners();
      },
      onError: (_) {
        // Stream error (e.g. transient connectivity) — keep last-known and let
        // a later load()/reconnect refresh. Don't let it kill the subscription.
      },
    );
  }

  /// Resolves the "other party" profile for each request (the sender for
  /// incoming, the recipient for outgoing).
  Future<List<RequestEntry>> _withProfiles(
    List<FriendRequest> reqs, {
    required bool useFrom,
  }) async {
    if (reqs.isEmpty) return const [];
    final ids =
        reqs.map((r) => useFrom ? r.fromId : r.toId).toSet().toList();
    final profiles = await _users.fetchProfiles(ids);
    final byId = {for (final p in profiles) p.id: p};
    return reqs.map((r) {
      final otherId = useFrom ? r.fromId : r.toId;
      return RequestEntry(
        r,
        byId[otherId] ?? AppUser(id: otherId, displayName: ''),
      );
    }).toList();
  }

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    // Ensure the incoming-requests stream is live (it may have been skipped at
    // construction if the uid wasn't ready, or dropped on a connectivity blip).
    if (_incomingSub == null) _listenIncoming();
    _loading = true;
    notifyListeners();
    try {
      // Friends from the current user's own profile (mutual friendIds).
      final me = await _users.fetchProfile(uid);
      _friendsList = me == null || me.friendIds.isEmpty
          ? []
          : await _users.fetchProfiles(me.friendIds);
      final out = await _friends.outgoingRequests(uid);
      _outgoing = await _withProfiles(out, useFrom: false);
    } catch (_) {
      // Keep last-known data on transient failure.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> sendRequest(String toId) async {
    final uid = _uid;
    if (uid == null) return;
    _analytics.buttonClicked('add_friend', params: {'target_user_id': toId});
    await _friends.sendRequest(fromId: uid, toId: toId);
    _analytics.actionSuccess('sendFriendRequest', params: {'target_user_id': toId});
    await load();
  }

  /// Cancels an outgoing pending request to [toId] (the Instagram-style toggle
  /// back to "not requested"). No-op if none is found.
  Future<void> cancelRequestTo(String toId) async {
    final uid = _uid;
    if (uid == null) return;
    // Use the freshest outgoing set; fall back to a fetch if not loaded yet.
    var outgoing = _outgoing;
    if (outgoing.every((e) => e.request.toId != toId)) {
      final fetched = await _friends.outgoingRequests(uid);
      outgoing = await _withProfiles(fetched, useFrom: false);
    }
    for (final e in outgoing) {
      if (e.request.toId == toId) {
        _analytics.buttonClicked('cancel_friend_request',
            params: {'target_user_id': toId});
        await _friends.cancelRequest(e.request);
        break;
      }
    }
    await load();
  }

  Future<void> unfriend(String otherId) async {
    final uid = _uid;
    if (uid == null) return;
    _analytics.buttonClicked('unfriend', params: {'target_user_id': otherId});
    await _friends.unfriend(me: uid, other: otherId);
    _analytics.actionSuccess('removeFriend', params: {'target_user_id': otherId});
    await load();
  }

  Future<void> accept(RequestEntry entry) async {
    _analytics.buttonClicked('accept_friend_request',
        params: {'requester_id': entry.request.fromId});
    await _friends.acceptRequest(entry.request);
    _analytics.actionSuccess('acceptFriend',
        params: {'requester_id': entry.request.fromId});
    await load();
  }

  Future<void> decline(RequestEntry entry) async {
    _analytics.buttonClicked('deny_friend_request',
        params: {'requester_id': entry.request.fromId});
    await _friends.declineRequest(entry.request);
    await load();
  }

  Future<void> cancel(RequestEntry entry) async {
    _analytics.buttonClicked('cancel_friend_request',
        params: {'target_user_id': entry.request.toId});
    await _friends.cancelRequest(entry.request);
    await load();
  }

  Future<void> search(String query) async {
    final uid = _uid;
    if (uid == null) return;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    try {
      _searchResults = await _friends.searchByName(query, excludeId: uid);
    } catch (_) {
      _searchResults = [];
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// Friendship status of [otherId] relative to the current user — for the
  /// profile action button.
  Future<FriendshipStatus> statusWith(String otherId) async {
    final uid = _uid;
    if (uid == null) return FriendshipStatus.none;
    return _friends.statusBetween(uid, otherId);
  }

  @override
  void dispose() {
    _safety?.removeListener(load);
    _incomingSub?.cancel();
    super.dispose();
  }
}
