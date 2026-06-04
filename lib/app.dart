import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/analytics/analytics_service.dart';
import 'core/app_scroll_behavior.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/auth/auth_service.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/mock_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/create/create_activity_screen.dart';
import 'features/feed/feed_controller.dart';
import 'features/home/home_shell.dart';

/// Root widget. Wires the dependency graph via Provider so every screen reads
/// abstractions ([ActivityRepository], [ChatRepository], [AuthService],
/// [AnalyticsService]) — never concretes.
class HangOutApp extends StatelessWidget {
  HangOutApp({
    super.key,
    required this.authService,
    required this.repository,
    required this.chatRepository,
    required this.analytics,
    UserRepository? userRepository,
  }) : userRepository = userRepository ?? _fallbackUserRepository;

  final AuthService authService;
  final ActivityRepository repository;
  final ChatRepository chatRepository;
  final UserRepository userRepository;
  final AnalyticsService analytics;

  // Used when no user repository is supplied (e.g. widget tests) so the app
  // still wires a UserRepository provider for the who's-going avatars.
  static final UserRepository _fallbackUserRepository = MockUserRepository();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AnalyticsService>.value(value: analytics),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<ActivityRepository>.value(value: repository),
        Provider<ChatRepository>.value(value: chatRepository),
        Provider<UserRepository>.value(value: userRepository),
        Provider<ActivityCreator>(create: (_) => ActivityCreator(repository)),
        ChangeNotifierProvider<FeedController>(
          create: (_) => FeedController(
            repository: repository,
            chatRepository: chatRepository,
            authService: authService,
            analytics: analytics,
            userRepository: userRepository,
          ),
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
        // Auth gate: rebuilds when sign-in state changes. Mock mode is
        // pre-signed-in, so it goes straight to the home shell.
        home: Consumer<AuthService>(
          builder: (context, auth, _) =>
              auth.isSignedIn ? const HomeShell() : const SignInScreen(),
        ),
      ),
    );
  }
}
