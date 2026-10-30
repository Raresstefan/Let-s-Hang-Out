import '../auth/auth_service.dart';
import '../repositories/activity_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/circle_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_repository.dart';
import '../../domain/models/message.dart';

/// Orchestrates the client-side cascade of Firestore cleanup that must run
/// while the about-to-be-deleted user's auth token is still valid, followed
/// by the actual Firebase Auth account deletion.
///
/// Activities/circles the user hosted/created are never deleted or modified —
/// they stay fully open for anyone to join, with `hostId`/`creatorId` left
/// pointing at the now-deleted uid as a historical record (see the "who's
/// going" display fallback in activity_details_screen.dart, which renders a
/// departed host instead of pretending they're still around). If a hosted
/// activity/circle already has a group chat (i.e. it reached 2+ members
/// before the deletion), that chat gets a system message announcing the
/// host's departure; a solo one has no chat and nobody to notify, so it gets
/// no action at all. Non-host/non-creator memberships ARE cleaned up — the
/// deleted user is removed from those activities'/circles' member lists,
/// exactly as if they'd tapped "leave."
///
/// Every cascade step is designed to be a safe no-op when its target is
/// already gone, so this is safe to call again in full after a partial
/// failure (e.g. [AccountDeletionRequiresRecentLogin] forces a sign-out and
/// retry — by the time that exception can surface, all Firestore cleanup
/// below has already completed).
class AccountDeletionService {
  AccountDeletionService({
    required AuthService authService,
    required ActivityRepository activityRepository,
    required ChatRepository chatRepository,
    required CircleRepository circleRepository,
    required FriendRepository friendRepository,
    required UserRepository userRepository,
  }) : _auth = authService,
       _activities = activityRepository,
       _chats = chatRepository,
       _circles = circleRepository,
       _friends = friendRepository,
       _users = userRepository;

  final AuthService _auth;
  final ActivityRepository _activities;
  final ChatRepository _chats;
  final CircleRepository _circles;
  final FriendRepository _friends;
  final UserRepository _users;

  /// Runs the full cascade (hosted/joined activities → created/joined
  /// circles → friendships → profile), then deletes the Firebase Auth
  /// account for [uid].
  Future<void> deleteAccountAndData(String uid, {String? password}) async {
    if (_auth.requiresPasswordForDeletion) {
      if (password == null || password.isEmpty) {
        throw const EmailAuthException(EmailAuthFailure.invalidCredentials);
      }
      await _auth.reauthenticateWithPassword(password);
    }
    // Reauthenticate before touching data so cancellation or a wrong password
    // cannot leave an account partially deleted.
    await _auth.prepareAccountDeletion();
    final profile = await _users.fetchProfile(uid);
    // Passed verbatim: the rules verify system-line names against the profile.
    final displayName = profile?.displayName ?? '';

    final myActivities = await _activities.fetchMyActivities(uid);
    final hostedActivities = myActivities.where((a) => a.hostId == uid);
    final memberOfActivities = myActivities.where((a) => a.hostId != uid);

    final myCircles = await _circles.myCircles(uid).first;
    final createdCircles = myCircles.where((c) => c.creatorId == uid);
    final memberOfCircles = myCircles.where((c) => c.creatorId != uid);

    for (final a in hostedActivities) {
      await _cleanupHostedActivity(a.id, uid, displayName);
    }
    for (final a in memberOfActivities) {
      await _activities.leaveActivity(a.id, uid);
      await _chats.removeMember(a.id, uid);
    }
    for (final c in createdCircles) {
      await _cleanupCreatedCircle(c.id, uid, displayName);
    }
    for (final c in memberOfCircles) {
      await _circles.leaveCircle(c.id, uid);
      await _chats.removeMember(c.id, uid);
    }

    if (profile != null) {
      for (final friendId in profile.friendIds) {
        await _friends.unfriend(me: uid, other: friendId);
      }
    }

    await _users.deleteProfile(uid);
    await _auth.deleteAccount();
  }

  /// A hosted activity is never deleted or modified. If it already has a group
  /// chat (2+ members), announce the host's departure there; otherwise there's
  /// no chat and no one to notify, so nothing happens.
  Future<void> _cleanupHostedActivity(
    String activityId,
    String uid,
    String displayName,
  ) async {
    final chat = await _chats.chatFor(activityId);
    if (chat == null) return;
    await _chats.sendSystemMessage(
      activityId,
      actorId: uid,
      event: SystemEvent.hostLeft,
      subjectId: uid,
      subjectName: displayName,
    );
  }

  /// A created circle is never deleted or modified — same treatment as a
  /// hosted activity (circle chats share the generic chat layer, keyed by
  /// circle id).
  Future<void> _cleanupCreatedCircle(
    String circleId,
    String uid,
    String displayName,
  ) async {
    final chat = await _chats.chatFor(circleId);
    if (chat == null) return;
    await _chats.sendSystemMessage(
      circleId,
      actorId: uid,
      event: SystemEvent.creatorLeft,
      subjectId: uid,
      subjectName: displayName,
    );
  }
}
