import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/circle.dart';

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
    required UserRepository userRepository,
    required AuthService authService,
    required AnalyticsService analytics,
  })  : _circles = circleRepository,
        _users = userRepository,
        _auth = authService,
        _analytics = analytics {
    _listen();
  }

  final CircleRepository _circles;
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
        _incoming = await _withProfiles(invites);
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

  @override
  void dispose() {
    _circlesSub?.cancel();
    _invitesSub?.cancel();
    super.dispose();
  }
}
