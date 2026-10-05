import '../../domain/models/report.dart';

/// User-level safety: private block lists and abuse reports.
abstract class SafetyRepository {
  /// Uids [uid] has blocked. Private to [uid].
  Future<Set<String>> fetchBlocked(String uid);

  Future<void> block({required String me, required String other});

  Future<void> unblock({required String me, required String other});

  /// Files a report for moderators. Write-only from the client.
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String details = '',
    String? chatId,
    String? activityId,
  });
}
