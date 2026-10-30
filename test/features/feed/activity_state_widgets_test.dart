import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/data/auth/auth_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/activity_repository.dart';
import 'package:hangout/data/repositories/chat_repository.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_friend_repository.dart';
import 'package:hangout/data/repositories/mock_safety_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/data/repositories/user_repository.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/features/chat/chat_screen.dart';
import 'package:hangout/features/feed/feed_controller.dart';
import 'package:hangout/features/my_activities/my_activities_screen.dart';
import 'package:hangout/features/safety/safety_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reproduce a delayed/stale repository snapshot without hiding it by refetching.
class _SnapshotRepository extends MockActivityRepository {
  late Activity snapshot;

  @override
  Future<List<Activity>> fetchMyActivities(String userId) async => [snapshot];
}

void main() {
  late _SnapshotRepository repo;
  late MockAuthService auth;
  late MockChatRepository chat;
  late ConsoleAnalyticsService analytics;
  late FeedController feed;
  late SafetyController safety;

  setUp(() async {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    repo = _SnapshotRepository();
    auth = MockAuthService();
    chat = MockChatRepository();
    analytics = ConsoleAnalyticsService();
    final users = MockUserRepository();
    feed = FeedController(
      repository: repo,
      chatRepository: chat,
      authService: auth,
      analytics: analytics,
      userRepository: users,
    );
    await feed.load();
    final a = feed.lookup('act-coffee')!;
    await feed.updateActivity(a.copyWith(title: 'Original coffee'));
    repo.snapshot = feed
        .lookup(a.id)!
        .copyWith(memberIds: [...a.memberIds, MockAuthService.mockUserId]);
    safety = SafetyController(
      safetyRepository: MockSafetyRepository(),
      friendRepository: MockFriendRepository(users),
      authService: auth,
      analytics: analytics,
    );
  });

  tearDown(() {
    feed.dispose();
    safety.dispose();
    auth.dispose();
  });

  Future<void> show(WidgetTester t, Widget screen) async {
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          Provider<ActivityRepository>.value(value: repo),
          Provider<ChatRepository>.value(value: chat),
          Provider<AnalyticsService>.value(value: analytics),
          Provider<UserRepository>(create: (_) => MockUserRepository()),
          ChangeNotifierProvider<FeedController>.value(value: feed),
          ChangeNotifierProvider<SafetyController>.value(value: safety),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Hangouts updates title and cancellation without a refresh', (
    t,
  ) async {
    // Make the real controller copy a member too.
    await t.runAsync(() => feed.join(repo.snapshot));
    await show(t, const MyActivitiesScreen());
    expect(find.text('Original coffee'), findsOneWidget);
    await t.runAsync(
      () => feed.updateActivity(
        feed.lookup('act-coffee')!.copyWith(title: 'Edited coffee'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Edited coffee'), findsOneWidget);
    expect(find.text('Original coffee'), findsNothing);
    await t.runAsync(() => feed.cancelActivity(feed.lookup('act-coffee')!));
    await t.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Edited coffee'), findsOneWidget);
  });

  testWidgets('activity chat header reacts to edits and cancellation', (
    t,
  ) async {
    expect(feed.lookup('act-coffee')!.title, 'Original coffee');
    await show(
      t,
      ChatScreen(
        chatId: 'act-coffee',
        title: 'Original coffee',
        activity: repo.snapshot,
      ),
    );
    expect(find.text('Original coffee'), findsOneWidget);
    await t.runAsync(
      () => feed.updateActivity(
        feed.lookup('act-coffee')!.copyWith(title: 'Edited coffee'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Edited coffee'), findsOneWidget);
    expect(find.text('Original coffee'), findsNothing);
    await t.runAsync(() => feed.cancelActivity(feed.lookup('act-coffee')!));
    await t.pumpAndSettle();
    expect(find.text('Edited coffee'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
