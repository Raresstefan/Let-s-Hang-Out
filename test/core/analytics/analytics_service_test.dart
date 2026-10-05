import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';

void main() {
  test('typed helpers emit stable events and parameters', () {
    final analytics = _RecordingAnalyticsService();

    analytics.activityOnLoad('User supplied title', activityId: 'activity-1');
    analytics.buttonClicked('join_activity', params: {'liked': true});
    analytics.inputTyping('search_activities');
    analytics.actionSuccess('createActivity');

    expect(analytics.events.map((event) => event.name), [
      'content_viewed',
      'button_clicked',
      'input_started',
      'action_succeeded',
    ]);
    expect(analytics.events[0].params, {
      'content_name': 'User supplied title',
      'activity_id': 'activity-1',
    });
    expect(analytics.events[1].params, {
      'liked': true,
      'button_name': 'join_activity',
    });
    expect(analytics.events[2].params, {'input_name': 'search_activities'});
    expect(analytics.events[3].params, {'action_name': 'createActivity'});
  });

  test('activity and input events are deduplicated per service instance', () {
    final analytics = _RecordingAnalyticsService();

    analytics.activityOnLoad('First title', activityId: 'activity-1');
    analytics.activityOnLoad('Changed title', activityId: 'activity-1');
    analytics.inputTyping('search_activities');
    analytics.inputTyping('search_activities');

    expect(analytics.events, hasLength(2));
  });
}

class _RecordingAnalyticsService extends AnalyticsService {
  final List<({String name, Map<String, Object?> params})> events = [];

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    events.add((name: name, params: params));
  }
}
