import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/core/notifications/reminder_scheduler.dart';
import 'package:hangout/core/notifications/reminder_service.dart';
import 'package:hangout/data/auth/auth_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/activity_repository.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/features/home/reminder_sync.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockActivityRepository repo;
  late MockAuthService auth;
  late _FakeScheduler scheduler;
  ReminderService? reminders;
  final me = MockAuthService.mockUserId;
  final start = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    repo = MockActivityRepository();
    auth = MockAuthService();
    scheduler = _FakeScheduler();
  });

  tearDown(() {
    reminders?.dispose();
    reminders = null;
    auth.dispose();
  });

  /// Planned in a circle, so it never shows up in the public feed.
  Future<Activity> circleHangout({List<String> memberIds = const []}) =>
      repo.createActivity(Activity(
        id: '',
        title: 'Circle padel',
        description: '',
        placeSuggestion: 'Club courts',
        startAt: start,
        hostId: 'user-host',
        category: ActivityCategory.padel,
        circleId: 'circle-1',
        memberIds: memberIds,
      ));

  /// Lets a change reach the listener and the re-sync it starts finish (the
  /// mock repository answers after 250 ms).
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> show(WidgetTester t) async {
    // Created inside the test's fake-async zone; futures it made in setUp
    // would only complete on the real event loop.
    final service = reminders = ReminderService(scheduler);
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          Provider<ActivityRepository>.value(value: repo),
          ChangeNotifierProvider<ReminderService>.value(value: service),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: [Locale('en', 'US')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ReminderSync(child: SizedBox()),
        ),
      ),
    );
    await settle(t);
  }

  _Scheduled? reminderFor(Activity a) =>
      scheduler.scheduled[ReminderService.idFor(a.id)];

  testWidgets(
      'a circle hangout reminder follows joining, host edits and cancelling '
      'while the app is open', (t) async {
    final hangout = (await t.runAsync(() => circleHangout()))!;
    await show(t);
    expect(reminderFor(hangout), isNull);

    await t.runAsync(() => repo.join(hangout.id, me));
    await settle(t);
    expect(reminderFor(hangout)?.at, start.subtract(ReminderService.lead),
        reason: 'joining schedules it without reopening the app');

    final later = start.add(const Duration(hours: 3));
    await t.runAsync(() => repo.updateActivity(
        hangout.copyWith(startAt: later, placeSuggestion: 'Rooftop courts')));
    await settle(t);
    expect(reminderFor(hangout)?.at, later.subtract(ReminderService.lead),
        reason: 'the host moved it');
    expect(reminderFor(hangout)?.body, contains('Rooftop courts'));

    final calls = scheduler.scheduleCalls;
    await t.runAsync(() => repo.toggleLike(hangout.id, 'user-host'));
    await settle(t);
    expect(scheduler.scheduleCalls, calls,
        reason: 'a like changes nothing a reminder shows');

    await t.runAsync(() => repo.cancelActivity(hangout.id));
    await settle(t);
    expect(reminderFor(hangout), isNull, reason: 'the host cancelled it');
  });

  testWidgets('being removed from a hangout cancels its reminder', (t) async {
    final hangout = (await t.runAsync(() => circleHangout(memberIds: [me])))!;
    await show(t);
    expect(reminderFor(hangout), isNotNull);

    await t.runAsync(() => repo.removeMember(hangout.id, me));
    await settle(t);
    expect(reminderFor(hangout), isNull);
  });
}

class _Scheduled {
  _Scheduled(this.at, this.body);
  final DateTime at;
  final String body;
}

class _FakeScheduler implements ReminderScheduler {
  final scheduled = <int, _Scheduled>{};
  int scheduleCalls = 0;

  @override
  Future<void> init({required void Function(String activityId) onOpen}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String activityId,
  }) async {
    scheduleCalls++;
    scheduled[id] = _Scheduled(at, body);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}
