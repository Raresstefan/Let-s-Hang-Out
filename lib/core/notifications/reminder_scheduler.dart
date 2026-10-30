import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules on-device notifications. Abstracted so the reminder logic can be
/// tested without the platform plugin.
abstract class ReminderScheduler {
  /// [onOpen] receives the activity id when the user taps a reminder,
  /// including the tap that launched the app.
  Future<void> init({required void Function(String activityId) onOpen});

  /// Asks the OS for permission to show notifications. Returns whether it
  /// was granted.
  Future<bool> requestPermission();

  /// Ids of reminders currently scheduled.
  Future<Set<int>> pendingIds();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String activityId,
  });

  Future<void> cancel(int id);
}

/// For the web demo and tests: does nothing.
class NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<void> init({required void Function(String activityId) onOpen}) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<Set<int>> pendingIds() async => const {};
  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String activityId,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
}

/// Android/iOS implementation backed by flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'hangout_reminders';
  static const _channelName = 'Hangout reminders';

  @override
  Future<void> init({required void Function(String activityId) onOpen}) async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked in context (first upcoming hangout), not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onOpen(id);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        payload != null &&
        payload.isNotEmpty) {
      onOpen(payload);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toSet();
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String activityId,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      // An absolute instant, so the device's time zone doesn't matter.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      title: title,
      body: body,
      payload: activityId,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A heads-up before hangouts you joined.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact avoids the exact-alarm permission; a few minutes' drift is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
