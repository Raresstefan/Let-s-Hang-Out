import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/mock_activity_repository.dart';
import '../../domain/models/activity.dart';

/// Activities the current user is enrolled in (hosting or joined).
class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  late Future<List<Activity>> _future;

  @override
  void initState() {
    super.initState();
    _future = context
        .read<ActivityRepository>()
        .fetchMyActivities(MockActivityRepository.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.read<AnalyticsService>().activityOnLoad('my_activities');

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('myActivities.title'))),
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(child: Text(l.tr('myActivities.empty')));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final hosting = a.hostId == MockActivityRepository.currentUserId;
              return ListTile(
                leading: CircleAvatar(child: Text(a.category.emoji)),
                title: Text(a.title),
                subtitle: Text(a.placeSuggestion),
                trailing: hosting
                    ? Chip(label: Text(l.tr('myActivities.hosting')))
                    : const Icon(Icons.chat_bubble_outline),
              );
            },
          );
        },
      ),
    );
  }
}
