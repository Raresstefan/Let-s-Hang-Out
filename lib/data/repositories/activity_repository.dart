import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';
import '../../domain/models/host_stats.dart';

/// Abstraction over activity persistence. The mock implementation backs the app
/// today; a FirestoreActivityRepository will implement the same contract later.
abstract class ActivityRepository {
  /// All activities, newest first. Optionally filtered by [category].
  Future<List<Activity>> fetchActivities({ActivityCategory? category});

  /// Activities the [userId] is enrolled in (joined or hosting).
  Future<List<Activity>> fetchMyActivities(String userId);

  /// A single activity by id, or null when it doesn't exist or the current
  /// user can't see it (e.g. a circle hangout they're not in). Used to open
  /// shared links.
  Future<Activity?> fetchActivity(String activityId);

  /// Live copy of one activity, updated whenever anyone (e.g. the host)
  /// changes it. Emits null when it no longer exists; errors when the user
  /// lost access to it.
  Stream<Activity?> watchActivity(String activityId);

  /// Live list of the activities [userId] is enrolled in, by start time.
  Stream<List<Activity>> watchMyActivities(String userId);

  Future<Activity> createActivity(Activity activity);

  /// Adds [userId] to the activity's members and returns the updated activity.
  Future<Activity> join(String activityId, String userId);

  /// Toggles [userId]'s like on the activity and returns the updated activity.
  Future<Activity> toggleLike(String activityId, String userId);

  /// Records [userId]'s post-hang [rating] (1–5) for the activity and returns
  /// the updated activity.
  Future<Activity> rateActivity(String activityId, String userId, int rating);

  /// Aggregate host reputation for [hostId] from the ratings on activities they
  /// host (average + counts). Shown on profiles.
  Future<HostStats> hostStats(String hostId);

  /// Removes [userId] from the activity's members (and their likedBy/ratings
  /// entries, if present) and returns the updated activity. A no-op-safe call:
  /// if [userId] isn't currently a member, the activity is returned unchanged.
  /// Used when a member leaves — including a non-host member deleting their
  /// account. A host is never removed this way; their activity is left intact.
  Future<Activity> leaveActivity(String activityId, String userId);

  /// Host-only: removes [memberId] from the activity and records them in
  /// `removedIds` so they can't rejoin. Returns the updated activity.
  Future<Activity> removeMember(String activityId, String memberId);

  /// Host-only: saves edited details (title, description, place, city, start
  /// time, category) of [activity] and returns the stored copy.
  Future<Activity> updateActivity(Activity activity);

  /// Host-only: marks the activity cancelled. Members keep it in their
  /// hangouts (shown as cancelled); nobody can join it any more.
  Future<Activity> cancelActivity(String activityId);
}
