import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';

/// Abstraction over activity persistence. The mock implementation backs the app
/// today; a FirestoreActivityRepository will implement the same contract later.
abstract class ActivityRepository {
  /// All activities, newest first. Optionally filtered by [category].
  Future<List<Activity>> fetchActivities({ActivityCategory? category});

  /// Activities the [userId] is enrolled in (joined or hosting).
  Future<List<Activity>> fetchMyActivities(String userId);

  Future<Activity> createActivity(Activity activity);

  /// Adds [userId] to the activity's members and returns the updated activity.
  Future<Activity> join(String activityId, String userId);
}
