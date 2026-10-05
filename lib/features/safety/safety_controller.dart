import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/friend_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../domain/models/friend_request.dart';
import '../../domain/models/report.dart';

/// The signed-in user's block list + reporting. Other controllers read
/// [isBlocked] to hide blocked users' activities, messages and requests.
class SafetyController extends ChangeNotifier {
  SafetyController({
    required SafetyRepository safetyRepository,
    required FriendRepository friendRepository,
    required AuthService authService,
    required AnalyticsService analytics,
  })  : _repo = safetyRepository,
        _friends = friendRepository,
        _auth = authService,
        _analytics = analytics {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final SafetyRepository _repo;
  final FriendRepository _friends;
  final AuthService _auth;
  final AnalyticsService _analytics;

  String? _loadedFor;
  Set<String> _blocked = const {};

  Set<String> get blockedIds => _blocked;

  bool isBlocked(String? uid) => uid != null && _blocked.contains(uid);

  void _onAuthChanged() {
    final uid = _auth.currentUserId;
    if (uid == _loadedFor) return;
    _loadedFor = uid;
    _blocked = const {};
    notifyListeners();
    if (uid != null) load();
  }

  Future<void> load() async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    try {
      _blocked = await _repo.fetchBlocked(uid);
      notifyListeners();
    } catch (_) {
      // Keep last-known; content filtering is best-effort client-side.
    }
  }

  /// Blocks [other] and severs friendship + pending requests both ways.
  Future<void> block(String other) async {
    final uid = _auth.currentUserId;
    if (uid == null || other == uid) return;
    _analytics.buttonClicked('block_user', params: {'target_user_id': other});
    await _repo.block(me: uid, other: other);
    _blocked = {..._blocked, other};
    notifyListeners();
    await _severTies(uid, other);
    // Second notify so listeners refresh after friendships are removed.
    notifyListeners();
    _analytics.actionSuccess('blockUser', params: {'target_user_id': other});
  }

  Future<void> unblock(String other) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    _analytics.buttonClicked('unblock_user', params: {'target_user_id': other});
    await _repo.unblock(me: uid, other: other);
    _blocked = {..._blocked}..remove(other);
    notifyListeners();
  }

  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String details = '',
    String? chatId,
    String? activityId,
  }) async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    _analytics.buttonClicked('report_${target.id}',
        params: {'target_id': targetId, 'reason': reason.id});
    await _repo.report(
      reporterId: uid,
      target: target,
      targetId: targetId,
      reason: reason,
      details: details.trim(),
      chatId: chatId,
      activityId: activityId,
    );
    _analytics.actionSuccess('submitReport', params: {'target': target.id});
  }

  /// Best-effort: each step is independent so one failure doesn't stop the rest.
  Future<void> _severTies(String me, String other) async {
    try {
      final status = await _friends.statusBetween(me, other);
      switch (status) {
        case FriendshipStatus.friends:
          await _friends.unfriend(me: me, other: other);
        case FriendshipStatus.requestedByMe:
          for (final r in await _friends.outgoingRequests(me)) {
            if (r.toId == other) await _friends.cancelRequest(r);
          }
        case FriendshipStatus.incoming:
          final incoming = await _friends.incomingRequests(me).first;
          for (final r in incoming) {
            if (r.fromId == other) await _friends.declineRequest(r);
          }
        case FriendshipStatus.none:
          break;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
