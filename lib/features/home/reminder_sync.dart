import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/notifications/reminder_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../domain/models/activity.dart';

/// Re-syncs hangout reminders while the signed-in home is shown: on open, on
/// returning to the app, and whenever the hangouts the user is in change —
/// joined, left, created or removed from, or moved, renamed or cancelled by
/// the host — including circle hangouts and changes made on other devices.
class ReminderSync extends StatefulWidget {
  const ReminderSync({super.key, required this.child});

  final Widget child;

  @override
  State<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends State<ReminderSync>
    with WidgetsBindingObserver {
  late final ReminderService _reminders = context.read<ReminderService>();
  StreamSubscription<List<Activity>>? _mine;
  String? _lastSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminders.addListener(_sync);
    _watchMine();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminders.removeListener(_sync);
    _mine?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_mine == null) _watchMine();
    _sync();
  }

  /// Follows the same query the reminders are built from, so it sees every
  /// change to the user's hangouts, whoever made it.
  void _watchMine() {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    _mine = context.read<ActivityRepository>().watchMyActivities(uid).listen(
      _onMineChanged,
      // The listener stops after an error; the next resume starts a new one.
      onError: (Object _) {
        _mine?.cancel();
        _mine = null;
      },
    );
  }

  void _onMineChanged(List<Activity> mine) {
    // Everything a reminder shows or depends on, and nothing else (likes,
    // chat activity), so unrelated updates don't reschedule.
    final signature = (mine
            .map((a) => [
                  a.id,
                  a.startAt.millisecondsSinceEpoch,
                  a.cancelled,
                  a.title,
                  a.placeSuggestion,
                ].join('|'))
            .toList()
          ..sort())
        .join('\n');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    _sync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    String time(DateTime t) => material.formatTimeOfDay(
          TimeOfDay.fromDateTime(t.toLocal()),
          alwaysUse24HourFormat: use24h,
        );
    try {
      final mine =
          await context.read<ActivityRepository>().fetchMyActivities(uid);
      await _reminders.sync(
        mine,
        title: (a) => l.tr(
          'reminders.title',
          {'title': a.title, 'time': time(a.startAt)},
        ),
        body: (a) => a.placeSuggestion.trim().isEmpty
            ? l.tr('reminders.bodyNoPlace')
            : l.tr('reminders.body', {'place': a.placeSuggestion.trim()}),
      );
    } catch (_) {
      // Best-effort; the next sync retries.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
