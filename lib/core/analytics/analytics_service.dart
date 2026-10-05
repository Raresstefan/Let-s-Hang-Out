import 'package:flutter/foundation.dart';

/// Analytics abstraction. The app only ever calls these typed helpers, never a
/// vendor SDK directly, so we can swap the console implementation for Firebase
/// Analytics / PostHog later by changing only [AnalyticsService] wiring.
///
/// Event names are stable and Firebase-compatible. The specific activity,
/// control, input, or action is carried in event parameters.
abstract class AnalyticsService {
  final Set<String> _firedOnLoad = <String>{};
  final Set<String> _firedTyping = <String>{};

  /// Logs a raw event. Prefer the typed helpers below.
  void logEvent(String name, {Map<String, Object?> params = const {}});

  /// Fired once per activity per session.
  void activityOnLoad(String activityTitle, {String? activityId}) {
    final key = activityId ?? activityTitle;
    if (_firedOnLoad.add(key)) {
      logEvent(
        'content_viewed',
        params: {
          'content_name': activityTitle,
          if (activityId != null) 'activity_id': activityId,
        },
      );
    }
  }

  void buttonClicked(
    String buttonName, {
    Map<String, Object?> params = const {},
  }) {
    logEvent('button_clicked', params: {...params, 'button_name': buttonName});
  }

  /// Fired once per input field per session.
  void inputTyping(String inputName) {
    if (_firedTyping.add(inputName)) {
      logEvent('input_started', params: {'input_name': inputName});
    }
  }

  void actionSuccess(String action, {Map<String, Object?> params = const {}}) {
    logEvent('action_succeeded', params: {...params, 'action_name': action});
  }
}

/// Console / debug implementation. Handles the de-duplication requirements so
/// callers don't have to.
class ConsoleAnalyticsService extends AnalyticsService {
  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('📊 [analytics] $name ${params.isEmpty ? '' : params}');
    }
  }
}
