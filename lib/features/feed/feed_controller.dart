import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';

/// Builds the localized "X joined the activity" system line. The l10n layer is
/// context-bound (widget tree); the controller has no BuildContext, so the
/// template lives here. Mirrors the `chat.systemJoined` key (en_US-only today).
String _systemJoinedLine(String name) => '$name joined the activity';

/// Drives the discover feed: loading, the active emoji filter, and joining.
class FeedController extends ChangeNotifier {
  FeedController({
    required ActivityRepository repository,
    required ChatRepository chatRepository,
    required AuthService authService,
    required AnalyticsService analytics,
    required UserRepository userRepository,
  })  : _repository = repository,
        _chatRepository = chatRepository,
        _authService = authService,
        _analytics = analytics,
        _userRepository = userRepository {
    load();
  }

  final ActivityRepository _repository;
  final ChatRepository _chatRepository;
  final AuthService _authService;
  final AnalyticsService _analytics;
  final UserRepository _userRepository;

  bool _loading = false;
  bool get loading => _loading;

  Object? _error;
  Object? get error => _error;

  /// A transient, user-facing message for the last failed action (e.g. a like
  /// that couldn't reach the backend). Set on failure; the UI reads it once via
  /// [consumeActionError] and shows a snackbar. Null when there's nothing to show.
  String? _actionError;

  /// Returns the pending action-error message (if any) and clears it, so each
  /// failure is surfaced exactly once.
  String? consumeActionError() {
    final msg = _actionError;
    _actionError = null;
    return msg;
  }

  List<Activity> _activities = [];
  List<Activity> get activities => _activities;

  /// null = "All" (no filter). Tapping an active emoji clears the filter.
  ActivityCategory? _activeFilter;
  ActivityCategory? get activeFilter => _activeFilter;

  /// Suggested activities surface first ("People liked this / signed up").
  List<Activity> get suggested =>
      _activities.where((a) => a.isSuggested).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _activities =
          await _repository.fetchActivities(category: _activeFilter);
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Toggle a filter. Tapping the active one again clears it (per the spec).
  Future<void> toggleFilter(ActivityCategory category) async {
    _analytics.buttonClicked('filter_${category.id}');
    _activeFilter = _activeFilter == category ? null : category;
    await load();
  }

  /// Clear any active filter (the "All" pill).
  Future<void> clearFilter() async {
    if (_activeFilter == null) return;
    _analytics.buttonClicked('filter_all');
    _activeFilter = null;
    await load();
  }

  Future<void> join(Activity activity) async {
    _analytics.buttonClicked('join_activity', params: {'activity_id': activity.id});
    final uid = _authService.currentUserId;
    if (uid == null) return; // not signed in — shouldn't happen behind the gate
    try {
      final updated = await _repository.join(activity.id, uid);
      final idx = _activities.indexWhere((a) => a.id == updated.id);
      if (idx != -1) {
        _activities[idx] = updated;
        notifyListeners();
      }
      _analytics.actionSuccess('joinActivity', params: {'activity_id': activity.id});

      // Group-chat rule: the host is member #1. The 2nd joiner creates the chat
      // (host + joiner); every subsequent joiner is added to the same chat.
      await _syncGroupChat(updated, uid);
    } catch (e) {
      _error = e;
      _actionError = 'joinFailed';
      notifyListeners();
    }
  }

  /// Toggles the current user's like on [activity] and updates the feed.
  ///
  /// Optimistic: the heart/count update instantly, then the write is sent. On
  /// failure the optimistic change is reverted and an error message is queued
  /// for the UI. (With Firestore offline persistence the write is queued rather
  /// than failing, so a brief offline blip still feels instant.)
  Future<void> toggleLike(Activity activity) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    final liked = !activity.isLikedBy(uid);
    _analytics.buttonClicked('like_activity',
        params: {'activity_id': activity.id, 'liked': liked});

    final idx = _activities.indexWhere((a) => a.id == activity.id);
    final previous = idx != -1 ? _activities[idx] : null;

    // Optimistic update.
    if (idx != -1 && previous != null) {
      final likedBy = liked
          ? [...previous.likedBy, uid]
          : previous.likedBy.where((id) => id != uid).toList();
      _activities[idx] = previous.copyWith(likedBy: likedBy);
      notifyListeners();
    }

    try {
      final updated = await _repository.toggleLike(activity.id, uid);
      if (idx != -1) {
        _activities[idx] = updated;
        notifyListeners();
      }
      _analytics.actionSuccess('likeActivity',
          params: {'activity_id': activity.id, 'liked': liked});
    } catch (e) {
      // Revert and surface a message.
      if (idx != -1 && previous != null) {
        _activities[idx] = previous;
      }
      _actionError = 'likeFailed';
      notifyListeners();
    }
  }

  /// Creates or grows the activity's group chat based on member count.
  ///
  /// At exactly 2 members the chat is created (host + 2nd joiner). Beyond that
  /// the joiner is added. ensureChat is idempotent (doc id == activityId), so
  /// calling it again is safe and self-heals an activity that reached 2 members
  /// before a chat was successfully created.
  Future<void> _syncGroupChat(Activity updated, String joinerId) async {
    final count = updated.memberIds.length;
    if (count < 2) return;
    if (count == 2) {
      await _chatRepository.ensureChat(
        updated.id,
        title: updated.title,
        memberIds: updated.memberIds,
      );
      _analytics.actionSuccess('createGroupChat',
          params: {'activity_id': updated.id});
      // Seed the fresh chat with a "joined" line for each founding member so it
      // doesn't open empty (host first, then the joiner).
      await _emitJoinedSystemLine(updated.id, updated.hostId, actorId: joinerId);
      await _emitJoinedSystemLine(updated.id, joinerId, actorId: joinerId);
    } else {
      // Ensure the chat exists (in case creation was missed) then add member.
      await _chatRepository.ensureChat(
        updated.id,
        title: updated.title,
        memberIds: updated.memberIds,
      );
      await _chatRepository.addMember(updated.id, joinerId);
      _analytics.actionSuccess('joinGroupChat',
          params: {'activity_id': updated.id});
      await _emitJoinedSystemLine(updated.id, joinerId, actorId: joinerId);
    }
  }

  /// Posts a "joined the activity" line for [memberId] to the chat. Resolves
  /// display name; [actorId] is the acting user's uid (satisfies the message
  /// write rule). Best-effort — a failed system line never blocks the join.
  Future<void> _emitJoinedSystemLine(
    String activityId,
    String memberId, {
    required String actorId,
  }) async {
    try {
      final profiles = await _userRepository.fetchProfiles([memberId]);
      var name = 'Someone';
      for (final p in profiles) {
        if (p.id == memberId && p.displayName.trim().isNotEmpty) {
          name = p.displayName;
          break;
        }
      }
      await _chatRepository.sendSystemMessage(
        activityId,
        actorId: actorId,
        text: _systemJoinedLine(name),
      );
    } catch (_) {
      // Ignore — the chat still works without the system line.
    }
  }
}
