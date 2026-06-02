import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/analytics/analytics_service.dart';
import 'core/app_scroll_behavior.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/activity_repository.dart';
import 'features/create/create_activity_screen.dart';
import 'features/feed/feed_controller.dart';
import 'features/home/home_shell.dart';

/// Root widget. Wires the dependency graph via Provider so every screen reads
/// abstractions ([ActivityRepository], [AnalyticsService]) — never concretes.
class HangOutApp extends StatelessWidget {
  const HangOutApp({
    super.key,
    required this.repository,
    required this.analytics,
  });

  final ActivityRepository repository;
  final AnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AnalyticsService>.value(value: analytics),
        Provider<ActivityRepository>.value(value: repository),
        Provider<ActivityCreator>(create: (_) => ActivityCreator(repository)),
        ChangeNotifierProvider<FeedController>(
          create: (_) =>
              FeedController(repository: repository, analytics: analytics),
        ),
      ],
      child: MaterialApp(
        title: 'Hang Out',
        debugShowCheckedModeBanner: false,
        // Smooth, phone-like momentum + trackpad-draggable horizontal lists.
        scrollBehavior: const AppScrollBehavior(),
        theme: AppTheme.light(),
        // Localization: JSON-backed, en_US only for now.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        home: const HomeShell(),
      ),
    );
  }
}
