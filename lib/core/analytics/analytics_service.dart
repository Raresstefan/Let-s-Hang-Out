import 'package:flutter/foundation.dart';

/// Analytics abstraction. The app only ever calls these typed helpers, never a
/// vendor SDK directly, so we can swap the console implementation for Firebase
/// Analytics / PostHog later by changing only [AnalyticsService] wiring.
///
/// Event naming follows the agreed pattern:
///   - Activity rendered:  `Hang:${activity_title}:OnLoad`  (deduped, no repeats)
///   - Button click:       `Hang:${button_name}:Clicked`
///   - Input typing:       `Hang:${input_name}:Typing`      (once per input)
///   - Service success:    `Hang:${action}:Success`
abstract class AnalyticsService {
  /// Logs a raw event. Prefer the typed helpers below.
  void logEvent(String name, {Map<String, Object?> params = const {}});

  /// `Hang:${activity_title}:OnLoad` — fired once per activity per session.
  void activityOnLoad(String activityTitle, {String? activityId});

  /// `Hang:${button_name}:Clicked`
  void buttonClicked(String buttonName, {Map<String, Object?> params = const {}});

  /// `Hang:${input_name}:Typing` — fired once per input field per session.
  void inputTyping(String inputName);

  /// `Hang:${action}:Success` — e.g. `userLogin`, `createActivity`.
  void actionSuccess(String action, {Map<String, Object?> params = const {}});
}

/// Console / debug implementation. Handles the de-duplication requirements so
/// callers don't have to.
class ConsoleAnalyticsService implements AnalyticsService {
  final Set<String> _firedOnLoad = <String>{};
  final Set<String> _firedTyping = <String>{};

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('📊 [analytics] $name ${params.isEmpty ? '' : params}');
    }
  }

  @override
  void activityOnLoad(String activityTitle, {String? activityId}) {
    final key = activityId ?? activityTitle;
    if (_firedOnLoad.add(key)) {
      logEvent('Hang:$activityTitle:OnLoad', params: {
        if (activityId != null) 'activity_id': activityId,
      });
    }
  }

  @override
  void buttonClicked(String buttonName, {Map<String, Object?> params = const {}}) {
    logEvent('Hang:$buttonName:Clicked', params: params);
  }

  @override
  void inputTyping(String inputName) {
    if (_firedTyping.add(inputName)) {
      logEvent('Hang:$inputName:Typing');
    }
  }

  @override
  void actionSuccess(String action, {Map<String, Object?> params = const {}}) {
    logEvent('Hang:$action:Success', params: params);
  }
}
