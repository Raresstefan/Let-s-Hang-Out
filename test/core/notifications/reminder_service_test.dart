import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/notifications/reminder_scheduler.dart';
import 'package:hangout/core/notifications/reminder_service.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2030, 1, 1, 12);

void main() {
  late _FakeScheduler scheduler;
  late ReminderService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scheduler = _FakeScheduler();
    service = ReminderService(scheduler, clock: () => _now);
  });

  Future<void> sync(List<Activity> mine) => service.sync(
        mine,
        title: (a) => 'T:${a.title}',
        body: (a) => 'B:${a.placeSuggestion}',
      );

  test('schedules one reminder [lead] before each upcoming hangout', () async {
    await sync([_activity('a', hours: 3), _activity('b', hours: 26)]);

    expect(scheduler.scheduled.keys, {
      ReminderService.idFor('a'),
      ReminderService.idFor('b'),
    });
    final a = scheduler.scheduled[ReminderService.idFor('a')]!;
    expect(a.at, _now.add(const Duration(hours: 1)));
    expect(a.title, 'T:a');
    expect(a.body, 'B:Park');
    expect(a.activityId, 'a');
  });

  test('skips hangouts whose reminder time has already passed', () async {
    await sync([
      _activity('soon', minutes: 90),
      _activity('past', hours: -2),
      _activity('later', hours: 3),
    ]);

    expect(scheduler.scheduled.keys, {ReminderService.idFor('later')});
  });

  test('cancels reminders for hangouts the user left', () async {
    await sync([_activity('a', hours: 3), _activity('b', hours: 4)]);
    await sync([_activity('b', hours: 4)]);

    expect(scheduler.scheduled.keys, {ReminderService.idFor('b')});
  });

  test('a moved start time reschedules the reminder', () async {
    await sync([_activity('a', hours: 3)]);
    await sync([_activity('a', hours: 5)]);

    expect(
      scheduler.scheduled[ReminderService.idFor('a')]!.at,
      _now.add(const Duration(hours: 3)),
    );
  });

  test('asks for permission once, only when there is something to remind',
      () async {
    await sync([]);
    expect(scheduler.permissionRequests, 0);

    await sync([_activity('a', hours: 3)]);
    await sync([_activity('a', hours: 3), _activity('b', hours: 4)]);
    expect(scheduler.permissionRequests, 1);
  });

  test('turning reminders off cancels them and stops scheduling', () async {
    await sync([_activity('a', hours: 3)]);
    await service.setEnabled(false);
    expect(scheduler.scheduled, isEmpty);

    await sync([_activity('a', hours: 3)]);
    expect(scheduler.scheduled, isEmpty);

    // The choice persists across app restarts.
    final restarted = ReminderService(scheduler, clock: () => _now);
    await restarted.sync([_activity('a', hours: 3)],
        title: (a) => '', body: (a) => '');
    expect(restarted.enabled, isFalse);
    expect(scheduler.scheduled, isEmpty);
  });

  test('cancelAll clears everything (sign-out)', () async {
    await sync([_activity('a', hours: 3), _activity('b', hours: 4)]);
    await service.cancelAll();
    expect(scheduler.scheduled, isEmpty);
  });

  test('caps the number of scheduled reminders, soonest first', () async {
    await sync([
      for (var i = 0; i < ReminderService.maxScheduled + 10; i++)
        _activity('x$i', hours: 3 + i),
    ]);

    expect(scheduler.scheduled.length, ReminderService.maxScheduled);
    expect(scheduler.scheduled.containsKey(ReminderService.idFor('x0')), isTrue);
    expect(
      scheduler.scheduled.containsKey(
          ReminderService.idFor('x${ReminderService.maxScheduled}')),
      isFalse,
    );
  });

  test('ids are stable, non-negative 31-bit ints', () {
    expect(ReminderService.idFor('abc'), ReminderService.idFor('abc'));
    expect(ReminderService.idFor('abc'), isNot(ReminderService.idFor('abd')));
    for (final s in ['', 'a', 'zzzzzzzzzzzzzzzzzzzzzzzz']) {
      final id = ReminderService.idFor(s);
      expect(id, inInclusiveRange(0, 0x7FFFFFFF));
    }
  });
}

Activity _activity(String id, {int hours = 0, int minutes = 0}) => Activity(
      id: id,
      title: id,
      description: '',
      placeSuggestion: 'Park',
      startAt: _now.add(Duration(hours: hours, minutes: minutes)),
      hostId: 'host',
      category: ActivityCategory.padel,
    );

class _Scheduled {
  _Scheduled(this.at, this.title, this.body, this.activityId);
  final DateTime at;
  final String title;
  final String body;
  final String activityId;
}

class _FakeScheduler implements ReminderScheduler {
  final scheduled = <int, _Scheduled>{};
  int permissionRequests = 0;

  @override
  Future<void> init({required void Function(String activityId) onOpen}) async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

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
    scheduled[id] = _Scheduled(at, title, body, activityId);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}
