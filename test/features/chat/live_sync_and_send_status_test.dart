import 'dart:async';

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
import 'package:hangout/domain/models/app_user.dart';
import 'package:hangout/features/chat/chat_screen.dart';
import 'package:hangout/features/feed/feed_controller.dart';
import 'package:hangout/features/my_activities/my_activities_screen.dart';
import 'package:hangout/features/safety/safety_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sends wait on [gate] (when set) and fail while [failNext] is true.
class _FlakyChat extends MockChatRepository {
  bool failNext = false;
  Completer<void>? gate;
  final List<String> attemptedIds = [];

  @override
  Future<void> sendMessage(
    String activityId, {
    required String messageId,
    required String senderId,
    required String text,
  }) async {
    attemptedIds.add(messageId);
    final g = gate;
    if (g != null) await g.future;
    if (failNext) throw StateError('offline');
    await super.sendMessage(
      activityId,
      messageId: messageId,
      senderId: senderId,
      text: text,
    );
  }
}

/// Ids in [gone] behave like deleted accounts: no profile comes back.
class _Users extends MockUserRepository {
  final Set<String> gone = {};

  @override
  Future<List<AppUser>> fetchProfiles(List<String> ids) async =>
      (await super.fetchProfiles(ids))
          .where((u) => !gone.contains(u.id))
          .toList();
}

void main() {
  late MockActivityRepository repo;
  late MockAuthService auth;
  late _FlakyChat chat;
  late _Users users;
  late ConsoleAnalyticsService analytics;
  late FeedController feed;
  late SafetyController safety;
  final me = MockAuthService.mockUserId;

  setUp(() async {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    repo = MockActivityRepository();
    auth = MockAuthService();
    chat = _FlakyChat();
    analytics = ConsoleAnalyticsService();
    users = _Users();
    feed = FeedController(
      repository: repo,
      chatRepository: chat,
      authService: auth,
      analytics: analytics,
      userRepository: users,
    );
    await feed.load();
    await repo.join('act-coffee', me);
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
          Provider<UserRepository>.value(value: users),
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

  // The host edits/cancels on their own device: the write goes straight to
  // the backend, not through this participant's FeedController.
  Future<void> hostEdits(WidgetTester t, String title) => t.runAsync(() async {
        final current = await repo.fetchActivity('act-coffee');
        await repo.updateActivity(current!.copyWith(title: title));
      });

  group('participant sees the host changes live', () {
    testWidgets('in Hangouts', (t) async {
      await show(t, const MyActivitiesScreen());
      expect(find.textContaining('Morning coffee'), findsOneWidget);

      await hostEdits(t, 'Coffee moved to Sunday');
      await t.pumpAndSettle();
      expect(find.text('Coffee moved to Sunday'), findsOneWidget);

      await t.runAsync(() => repo.cancelActivity('act-coffee'));
      await t.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);
    });

    test('follow() keeps the shared copy fresh until cancelled', () async {
      // What the details screen subscribes to while it's open.
      final sub = feed.follow('act-coffee');
      final current = await repo.fetchActivity('act-coffee');
      await repo.updateActivity(current!.copyWith(title: 'Moved to Sunday'));
      await pumpEventQueue();
      expect(feed.lookup('act-coffee')!.title, 'Moved to Sunday');

      await sub.cancel();
      await repo.updateActivity(current.copyWith(title: 'Ignored'));
      await pumpEventQueue();
      expect(feed.lookup('act-coffee')!.title, 'Moved to Sunday');
    });

    testWidgets('in the chat header', (t) async {
      final a = feed.lookup('act-coffee')!;
      await show(t, ChatScreen(chatId: a.id, title: a.title, activity: a));
      await t.runAsync(() => repo.cancelActivity('act-coffee'));
      await t.pumpAndSettle();
      expect(find.text('Cancelled'), findsOneWidget);
    });
  });

  group('sending a chat message', () {
    Future<void> send(WidgetTester t, String text) async {
      await t.enterText(find.byType(TextField), text);
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump();
    }

    String composerText(WidgetTester t) =>
        t.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('shows a clock, then a single check once saved', (t) async {
      await show(t, const ChatScreen(chatId: 'chat-ok', title: 'Chat'));
      chat.gate = Completer<void>();
      await send(t, 'On my way');

      expect(find.text('On my way'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(composerText(t), isEmpty);

      chat.gate!.complete();
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.text('On my way'), findsOneWidget);
    });

    testWidgets('keeps a failed message and retries it without duplicates', (
      t,
    ) async {
      await show(t, const ChatScreen(chatId: 'chat-fail', title: 'Chat'));
      chat.failNext = true;
      await send(t, 'See you at 6');
      await t.pumpAndSettle();

      expect(find.text('See you at 6'), findsOneWidget);
      expect(find.text('Not sent. Tap to retry.'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);

      chat.failNext = false;
      await t.tap(find.text('See you at 6'));
      await t.pumpAndSettle();

      expect(find.text('Not sent. Tap to retry.'), findsNothing);
      expect(find.text('See you at 6'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(chat.attemptedIds, hasLength(2));
      expect(chat.attemptedIds.toSet(), hasLength(1),
          reason: 'a retry reuses the message id so it cannot duplicate');
    });

    testWidgets('a failed message survives leaving and reopening the chat', (
      t,
    ) async {
      await show(t, const ChatScreen(chatId: 'chat-reopen', title: 'Chat'));
      chat.failNext = true;
      await send(t, 'Still there?');
      await t.pumpAndSettle();
      await show(t, const SizedBox());
      await show(t, const ChatScreen(chatId: 'chat-reopen', title: 'Chat'));
      expect(find.text('Still there?'), findsOneWidget);
      expect(find.text('Not sent. Tap to retry.'), findsOneWidget);
    });
  });

  testWidgets('group messages name the sender once per run', (t) async {
    await users.upsertIdentity('user-bob', displayName: 'Bob');
    await users.upsertIdentity('user-cara', displayName: 'Cara');
    users.gone.add('user-gone');
    Future<void> say(String from, String text) => chat.sendMessage(
          'chat-group',
          messageId: text,
          senderId: from,
          text: text,
        );
    await say('user-bob', 'Hi all');
    await say('user-bob', 'Who brings snacks?');
    await say('user-cara', 'Me!');
    await say(me, 'Great');
    await say('user-bob', 'See you there');
    await say('user-gone', 'Bye');

    await show(t, const ChatScreen(chatId: 'chat-group', title: 'Group'));

    expect(find.text('Bob'), findsNWidgets(2),
        reason: "Bob's two runs are split by Cara and me");
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Someone'), findsOneWidget,
        reason: 'a deleted account still gets a label');
    expect(find.text('Rares'), findsNothing,
        reason: 'my own messages are not labelled');
    // Each name sits in the bubble of the message that starts the run.
    for (final (name, text) in [
      ('Bob', 'Hi all'),
      ('Cara', 'Me!'),
      ('Bob', 'See you there'),
      ('Someone', 'Bye'),
    ]) {
      final column = find.ancestor(
        of: find.text(text),
        matching: find.byType(Column),
      ).first;
      expect(
        find.descendant(of: column, matching: find.text(name)),
        findsOneWidget,
        reason: '"$text" should be labelled $name',
      );
    }
  });
}
