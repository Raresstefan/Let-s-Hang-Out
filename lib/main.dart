import 'package:flutter/material.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/config/app_config.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/mock_activity_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: choose implementations based on AppConfig.
  // Today everything is mock so the app runs with zero backend setup.
  // To wire Firebase: see README "Wiring the real backend".
  final AnalyticsService analytics = ConsoleAnalyticsService();
  final ActivityRepository repository = AppConfig.useMockBackend
      ? MockActivityRepository()
      : MockActivityRepository(); // TODO: FirestoreActivityRepository()

  runApp(HangOutApp(repository: repository, analytics: analytics));
}
