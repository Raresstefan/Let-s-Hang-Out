import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/activity.dart';
import 'reminder_scheduler.dart';

/// Keeps one on-device reminder per upcoming hangout the user is in, fired
/// [lead] before it starts. Free (no server): reminders are scheduled on the
/// phone, re-synced whenever the user's hangouts may have changed.
///
/// Android delivers inexact alarms up to an hour late, so a 2-hour lead means
/// the reminder lands 1–2 hours before the start. The text states the start
/// time rather than a countdown so it's right either way.
class ReminderService extends ChangeNotifier {
  ReminderService(this._scheduler, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final ReminderScheduler _scheduler;
  final DateTime Function() _now;

  static const lead = Duration(hours: 2);

  /// iOS keeps at most 64 pending local notifications per app.
  static const maxScheduled = 50;

  static const _enabledKey = 'reminders.enabled';
  static const _askedKey = 'reminders.permissionAsked';

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void>? _loading;
  Future<void> _sync = Future.value();

  Future<void> init({required void Function(String activityId) onOpen}) async {
    await _scheduler.init(onOpen: onOpen);
    await _load();
  }

  Future<void> _load() => _loading ??= () async {
        final prefs = await SharedPreferences.getInstance();
        _enabled = prefs.getBool(_enabledKey) ?? true;
        notifyListeners();
      }();

  /// Stable notification id for an activity (31-bit FNV-1a of its id).
  static int idFor(String activityId) {
    var h = 0x811c9dc5;
    for (final c in activityId.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  /// Turns reminders on or off. Turning on asks for permission if needed.
  Future<void> setEnabled(bool value) async {
    await _load();
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (value) {
      await prefs.setBool(_askedKey, true);
      await _scheduler.requestPermission();
    } else {
      await cancelAll();
    }
  }

  /// Makes the scheduled reminders match [mine] (the user's hangouts).
  /// [title] and [body] build the localized text. Calls are serialized.
  Future<void> sync(
    List<Activity> mine, {
    required String Function(Activity) title,
    required String Function(Activity) body,
  }) {
    return _sync = _sync.catchError((Object _) {}).then(
          (_) => _doSync(mine, title: title, body: body),
        );
  }

  Future<void> _doSync(
    List<Activity> mine, {
    required String Function(Activity) title,
    required String Function(Activity) body,
  }) async {
    await _load();
    final pending = await _scheduler.pendingIds();
    if (!_enabled) {
      for (final id in pending) {
        await _scheduler.cancel(id);
      }
      return;
    }
    final now = _now();
    // Skip hangouts whose reminder time has already passed (e.g. joined
    // 30 minutes before the start).
    final upcoming = mine
        .where((a) => !a.cancelled && a.startAt.subtract(lead).isAfter(now))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final wanted = {
      for (final a in upcoming.take(maxScheduled)) idFor(a.id): a,
    };

    for (final id in pending.difference(wanted.keys.toSet())) {
      await _scheduler.cancel(id);
    }
    if (wanted.isEmpty) return;

    // Ask in context: the first time the user has a hangout to be reminded of.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_askedKey) ?? false)) {
      await prefs.setBool(_askedKey, true);
      await _scheduler.requestPermission();
    }

    // Re-scheduling an existing id replaces it, which picks up time changes.
    for (final e in wanted.entries) {
      final a = e.value;
      await _scheduler.schedule(
        id: e.key,
        at: a.startAt.subtract(lead),
        title: title(a),
        body: body(a),
        activityId: a.id,
      );
    }
  }

  /// Removes every scheduled reminder (sign-out, account deletion, opt-out).
  Future<void> cancelAll() {
    return _sync = _sync.catchError((Object _) {}).then((_) async {
      for (final id in await _scheduler.pendingIds()) {
        await _scheduler.cancel(id);
      }
    });
  }
}
