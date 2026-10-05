import 'package:flutter/foundation.dart';

import '../../domain/models/report.dart';
import 'safety_repository.dart';

class MockSafetyRepository implements SafetyRepository {
  final Map<String, Set<String>> _blocks = {};

  @override
  Future<Set<String>> fetchBlocked(String uid) async =>
      {...?_blocks[uid]};

  @override
  Future<void> block({required String me, required String other}) async =>
      (_blocks[me] ??= {}).add(other);

  @override
  Future<void> unblock({required String me, required String other}) async =>
      _blocks[me]?.remove(other);

  @override
  Future<void> report({
    required String reporterId,
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String details = '',
    String? chatId,
    String? activityId,
  }) async {
    debugPrint('[mock report] $reporterId → ${target.id}:$targetId '
        '(${reason.id}) $details');
  }
}
