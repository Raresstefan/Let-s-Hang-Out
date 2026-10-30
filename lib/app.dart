import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/analytics/analytics_service.dart';
import 'core/app_scroll_behavior.dart';
import 'core/l10n/app_localizations.dart';
import 'core/links/deep_link_service.dart';
import 'core/notifications/reminder_scheduler.dart';
import 'core/notifications/reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'data/account/account_deletion_service.dart';
import 'data/auth/auth_service.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/circle_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/mock_circle_repository.dart';
import 'data/repositories/mock_friend_repository.dart';
import 'data/repositories/mock_safety_repository.dart';
import 'data/repositories/mock_user_repository.dart';
import 'data/repositories/safety_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/storage/activity_cover_storage.dart';
import 'data/storage/inline_activity_cover_storage.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/circles/circles_controller.dart';
import 'features/create/activity_creator.dart';
import 'features/feed/feed_controller.dart';
import 'features/friends/friends_controller.dart';
import 'features/home/deep_link_opener.dart';
import 'features/home/home_shell.dart';
import 'features/home/reminder_sync.dart';
import 'features/legal/terms_gate.dart';
import 'features/safety/safety_controller.dart';

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
    ActivityCoverStorage? coverStorage,
    DeepLinkService? deepLinks,
    ReminderService? reminders,
    UserRepository? userRepository,
    FriendRepository? friendRepository,
    CircleRepository? circleRepository,
    SafetyRepository? safetyRepository,
  }) : safetyRepository = safetyRepository ?? MockSafetyRepository(),
       coverStorage = coverStorage ?? InlineActivityCoverStorage(),
       deepLinks = deepLinks ?? DeepLinkService.none(),
       reminders = reminders ?? ReminderService(NoopReminderScheduler()),
       userRepository = userRepository ?? _fallbackUserRepository,
       friendRepository = friendRepository ?? _fallbackFriendRepository,
       circleRepository =
           circleRepository ?? _fallbackCircleRepository(chatRepository);

  final AuthService authService;
  final ActivityRepository repository;
  final ChatRepository chatRepository;
  final UserRepository userRepository;
  final FriendRepository friendRepository;
  final CircleRepository circleRepository;
  final SafetyRepository safetyRepository;
  final AnalyticsService analytics;
  final ActivityCoverStorage coverStorage;
  final DeepLinkService deepLinks;
  final ReminderService reminders;

  // Lets the auth gate pop any routes pushed on top of the root (e.g. the
  // Profile page, opened via Navigator.push from the avatar button) when
  // signing out. Without this, MaterialApp.home swapping to SignInScreen only
  // replaces the *initial* route — a still-pushed page stays on top of the
  // stack, so the app appears "stuck" until that page is popped manually.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
        Provider<SafetyRepository>.value(value: safetyRepository),
        Provider<ActivityCoverStorage>.value(value: coverStorage),
        ChangeNotifierProvider<DeepLinkService>.value(value: deepLinks),
        ChangeNotifierProvider<ReminderService>.value(value: reminders),
        Provider<ActivityCreator>(
          create: (_) => ActivityCreator(repository, coverStorage),
        ),
        Provider<AccountDeletionService>(
          create: (_) => AccountDeletionService(
            authService: authService,
            activityRepository: repository,
            chatRepository: chatRepository,
            circleRepository: circleRepository,
            friendRepository: friendRepository,
            userRepository: userRepository,
          ),
        ),
        // Before Feed/Friends: they filter by the block list.
        ChangeNotifierProvider<SafetyController>(
          create: (_) => SafetyController(
            safetyRepository: safetyRepository,
            friendRepository: friendRepository,
            authService: authService,
            analytics: analytics,
          ),
        ),
        ChangeNotifierProvider<FeedController>(
          create: (ctx) => FeedController(
            repository: repository,
            chatRepository: chatRepository,
            authService: authService,
            analytics: analytics,
            userRepository: userRepository,
            safety: ctx.read<SafetyController>(),
          ),
        ),
        ChangeNotifierProvider<FriendsController>(
          create: (ctx) => FriendsController(
            friendRepository: friendRepository,
            userRepository: userRepository,
            authService: authService,
            analytics: analytics,
            safety: ctx.read<SafetyController>(),
          ),
        ),
        ChangeNotifierProvider<CirclesController>(
          create: (_) => CirclesController(
            circleRepository: circleRepository,
            chatRepository: chatRepository,
            userRepository: userRepository,
            authService: authService,
            analytics: analytics,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
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
          builder: (context, auth, _) {
            if (!auth.isSignedIn) {
              // Swapping `home` alone only replaces the *initial* route — any
              // page pushed on top (e.g. Profile, opened via Navigator.push)
              // stays on the stack and hides the sign-in screen underneath.
              // Pop back to root on every sign-out so it's actually visible.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigatorKey.currentState?.popUntil((r) => r.isFirst);
              });
              // Don't leave this user's reminders for whoever signs in next.
              reminders.cancelAll();
            }
            // Signed-in users must accept the community rules before using
            // the app (App Store 1.2 / Play UGC policy).
            return auth.isEmailVerificationPending
                ? const EmailVerificationScreen()
                : auth.isSignedIn
                ? const TermsGate(
                    child: DeepLinkOpener(child: ReminderSync(child: HomeShell())),
                  )
                : const SignInScreen();
          },
        ),
      ),
    );
  }
}
