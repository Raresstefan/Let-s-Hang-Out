import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/mock_activity_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/activity_category.dart';

/// Drives the discover feed: loading, the active emoji filter, and joining.
class FeedController extends ChangeNotifier {
  FeedController({
    required ActivityRepository repository,
    required AnalyticsService analytics,
  })  : _repository = repository,
        _analytics = analytics {
    load();
  }

  final ActivityRepository _repository;
  final AnalyticsService _analytics;

  bool _loading = false;
  bool get loading => _loading;

  Object? _error;
  Object? get error => _error;

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
    try {
      final updated =
          await _repository.join(activity.id, MockActivityRepository.currentUserId);
      final idx = _activities.indexWhere((a) => a.id == updated.id);
      if (idx != -1) {
        _activities[idx] = updated;
        notifyListeners();
      }
      _analytics.actionSuccess('joinActivity', params: {'activity_id': activity.id});
    } catch (e) {
      _error = e;
      notifyListeners();
    }
  }
}
