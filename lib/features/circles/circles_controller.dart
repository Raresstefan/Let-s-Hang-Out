import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/circle.dart';
import '../../domain/models/message.dart';

/// A circle invite paired with the inviter's resolved profile, for display.
class CircleInviteEntry {
  const CircleInviteEntry(this.invite, this.fromUser);
  final CircleInvite invite;
  final AppUser fromUser;
}

/// Drives the Circles tab: the user's circles (live), incoming invites (live,
/// for the nav badge), and create/invite/accept/decline/cancel actions.
class CirclesController extends ChangeNotifier {
  CirclesController({
    required CircleRepository circleRepository,
    required ChatRepository chatRepository,
    required UserRepository userRepository,
    required AuthService authService,
    required AnalyticsService analytics,
  })  : _circles = circleRepository,
        _chats = chatRepository,
        _users = userRepository,
        _auth = authService,
        _analytics = analytics {
    // App-wide provider that outlives sign-out: re-bind to whoever signs in
    // next instead of keeping the previous account's circles/invites and
    // their dead (permission-denied) streams.
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final CircleRepository _circles;
  final ChatRepository _chats;
  final UserRepository _users;
  final AuthService _auth;
  final AnalyticsService _analytics;

  StreamSubscription<List<Circle>>? _circlesSub;
  StreamSubscription<List<CircleInvite>>? _invitesSub;

  List<Circle> _myCircles = [];
  List<Circle> get myCircles => _myCircles;

  List<CircleInviteEntry> _incoming = [];
  List<CircleInviteEntry> get incoming => _incoming;
  int get incomingCount => _incoming.length;

  String? get _uid => _auth.currentUserId;

  /// The user this controller's state and streams belong to.
  String? _boundUid;

  void _onAuthChanged() {
    final uid = _uid;
    if (uid == _boundUid) return;
    _boundUid = uid;
    _circlesSub?.cancel();
    _invitesSub?.cancel();
    _circlesSub = null;
    _invitesSub = null;
    _myCircles = [];
    _incoming = [];
    notifyListeners();
    if (uid != null) _listen();
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    _circlesSub?.cancel();
    _circlesSub = _circles.myCircles(uid).listen(
      (list) {
        _myCircles = list;
        notifyListeners();
      },
      onError: (_) {},
    );
    _invitesSub?.cancel();
    _invitesSub = _circles.incomingInvites(uid).listen(
      (invites) async {
        final entries = await _withProfiles(invites);
        if (uid != _boundUid) return; // signed out/switched meanwhile
        _incoming = entries;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  /// Call when the signed-in user becomes available after construction.
  void ensureListening() {
    if (_circlesSub == null || _invitesSub == null) _listen();
  }

  Future<List<CircleInviteEntry>> _withProfiles(
      List<CircleInvite> invites) async {
    if (invites.isEmpty) return const [];
    final ids = invites.map((i) => i.fromId).toSet().toList();
    final profiles = await _users.fetchProfiles(ids);
    final byId = {for (final p in profiles) p.id: p};
    return invites
        .map((i) => CircleInviteEntry(
              i,
              byId[i.fromId] ?? AppUser(id: i.fromId, displayName: ''),
            ))
        .toList();
  }

  Future<Circle?> createCircle({
    required String name,
    String? emoji,
    List<String> inviteeIds = const [],
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    _analytics.buttonClicked('create_circle');
    final circle =
        await _circles.createCircle(name: name, emoji: emoji, creatorId: uid);
    _analytics.actionSuccess('createCircle', params: {'circle_id': circle.id});
    // Invite the chosen friends.
    for (final id in inviteeIds) {
      await _circles.invite(circle: circle, fromId: uid, toId: id);
    }
    return circle;
  }

  Future<void> invite(Circle circle, String toId) async {
    final uid = _uid;
    if (uid == null) return;
    _analytics.buttonClicked('invite_to_circle',
        params: {'circle_id': circle.id, 'target_user_id': toId});
    await _circles.invite(circle: circle, fromId: uid, toId: toId);
    _analytics.actionSuccess('inviteToCircle', params: {'circle_id': circle.id});
  }

  Future<void> accept(CircleInviteEntry entry) async {
    _analytics.buttonClicked('accept_circle_invite',
        params: {'circle_id': entry.invite.circleId});
    await _circles.acceptInvite(entry.invite);
    _analytics.actionSuccess('acceptCircleInvite',
        params: {'circle_id': entry.invite.circleId});
  }

  Future<void> decline(CircleInviteEntry entry) async {
    _analytics.buttonClicked('deny_circle_invite',
        params: {'circle_id': entry.invite.circleId});
    await _circles.declineInvite(entry.invite);
  }

  /// Non-creator leaves [circle] and its chat. Throws on failure.
  Future<void> leave(Circle circle) async {
    final uid = _uid;
    if (uid == null || circle.creatorId == uid) return;
    _analytics.buttonClicked('leave_circle', params: {'circle_id': circle.id});
    // Announce first: only chat members may post.
    try {
      if (await _chats.chatFor(circle.id) != null) {
        final profile = await _users.fetchProfile(uid);
        await _chats.sendSystemMessage(
          circle.id,
          actorId: uid,
          event: SystemEvent.left,
          subjectId: uid,
          subjectName: profile?.displayName ?? '',
        );
      }
    } catch (_) {/* best-effort */}
    await _circles.leaveCircle(circle.id, uid);
    try {
      await _chats.removeMember(circle.id, uid);
    } catch (_) {/* best-effort, like account deletion */}
    _myCircles = _myCircles.where((c) => c.id != circle.id).toList();
    notifyListeners();
    _analytics.actionSuccess('leaveCircle', params: {'circle_id': circle.id});
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _circlesSub?.cancel();
    _invitesSub?.cancel();
    super.dispose();
  }
}
