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
import 'data/repositories/circle_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/mock_circle_repository.dart';
import 'data/repositories/mock_friend_repository.dart';
import 'data/repositories/mock_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/circles/circles_controller.dart';
import 'features/create/create_activity_screen.dart';
import 'features/feed/feed_controller.dart';
import 'features/friends/friends_controller.dart';
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
    FriendRepository? friendRepository,
    CircleRepository? circleRepository,
  })  : userRepository = userRepository ?? _fallbackUserRepository,
        friendRepository = friendRepository ?? _fallbackFriendRepository,
        circleRepository = circleRepository ?? _fallbackCircleRepository(chatRepository);

  final AuthService authService;
  final ActivityRepository repository;
  final ChatRepository chatRepository;
  final UserRepository userRepository;
  final FriendRepository friendRepository;
  final CircleRepository circleRepository;
  final AnalyticsService analytics;

  // Used when no repositories are supplied (e.g. widget tests) so the app still
  // wires the providers the screens read. The fallback friend repo shares the
  // fallback user store so friendIds + search stay consistent.
  static final MockUserRepository _fallbackUserRepository =
      MockUserRepository();
  static final FriendRepository _fallbackFriendRepository =
      MockFriendRepository(_fallbackUserRepository);
  static CircleRepository _fallbackCircleRepository(ChatRepository chats) =>
      MockCircleRepository(chats);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AnalyticsService>.value(value: analytics),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<ActivityRepository>.value(value: repository),
        Provider<ChatRepository>.value(value: chatRepository),
        Provider<UserRepository>.value(value: userRepository),
        Provider<FriendRepository>.value(value: friendRepository),
        Provider<CircleRepository>.value(value: circleRepository),
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
        ChangeNotifierProvider<FriendsController>(
          create: (_) => FriendsController(
            friendRepository: friendRepository,
            userRepository: userRepository,
            authService: authService,
            analytics: analytics,
          ),
        ),
        ChangeNotifierProvider<CirclesController>(
          create: (_) => CirclesController(
            circleRepository: circleRepository,
            userRepository: userRepository,
            authService: authService,
            analytics: analytics,
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
