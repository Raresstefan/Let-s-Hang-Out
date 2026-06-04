import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../domain/models/activity.dart';
import '../chat/chat_screen.dart';

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
    _future = _load();
  }

  Future<List<Activity>> _load() {
    final uid = context.read<AuthService>().currentUserId!;
    return context.read<ActivityRepository>().fetchMyActivities(uid);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.read<AnalyticsService>().activityOnLoad('my_activities');
    final uid = context.read<AuthService>().currentUserId;

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('myActivities.title'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            // Scrollable so pull-to-refresh works from the empty state too.
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(l.tr('myActivities.empty'))),
              ],
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final hosting = a.hostId == uid;
              // A chat exists once the activity has at least 2 members.
              final hasChat = a.memberIds.length >= 2;
              return ListTile(
                leading: CircleAvatar(child: Text(a.category.emoji)),
                title: Text(a.title),
                subtitle: Text(a.placeSuggestion),
                trailing: hosting
                    ? Chip(label: Text(l.tr('myActivities.hosting')))
                    : const Icon(Icons.chat_bubble_outline),
                enabled: hasChat,
                onTap: hasChat
                    ? () {
                        context.read<AnalyticsService>().buttonClicked(
                          'open_chat',
                          params: {'activity_id': a.id},
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              activityId: a.id,
                              title: a.title,
                            ),
                          ),
                        );
                      }
                    : null,
              );
            },
          );
        },
        ),
      ),
    );
  }
}
