import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

class FirebaseAnalyticsService extends AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    final parameters = <String, Object>{};
    for (final MapEntry(:key, :value) in params.entries) {
      if (value == null) continue;
      parameters[key] = switch (value) {
        bool value => value ? 1 : 0,
        String() || int() || double() => value,
        _ => throw ArgumentError.value(
          value,
          key,
          'Firebase Analytics parameters must be strings or numbers',
        ),
      };
    }

    unawaited(_send(name, parameters));
  }

  Future<void> _send(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters.isEmpty ? null : parameters,
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Firebase Analytics',
          context: ErrorDescription('while logging event "$name"'),
        ),
      );
    }
  }
}
