import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/activity.dart';
import '../activity_details/activity_details_screen.dart';
import '../chat/chat_screen.dart';
import '../feed/feed_controller.dart';
import '../post_hang/recap_card.dart';
import '../profile/profile_avatar_button.dart';

/// Activities the current user is enrolled in (hosting or joined).
class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  late Future<List<Activity>> _future;

  /// Activity ids the user just rated this session — drop their recap card
  /// immediately, without waiting on a refetch (avoids the cache/refresh race).
  final Set<String> _locallyRated = {};

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
      appBar: AppBar(
        title: Text(l.tr('myActivities.title')),
        actions: const [ProfileAvatarButton()],
      ),
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
          // Split into Upcoming (now or future) and Past (started already),
          // each newest-relevant first. Past un-recapped activities surface a
          // "How was it?" recap card.
          final now = DateTime.now();
          final upcoming = items.where((a) => !a.startAt.isBefore(now)).toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
          final past = items.where((a) => a.startAt.isBefore(now)).toList()
            ..sort((a, b) => b.startAt.compareTo(a.startAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionHeader(l.tr('postHang.upcoming')),
                for (final a in upcoming) _activityTile(context, a, uid, l),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader(l.tr('postHang.past')),
                for (final a in past)
                  (uid != null &&
                          !a.isRatedBy(uid) &&
                          !_locallyRated.contains(a.id))
                      ? RecapCard(
                          activity: a,
                          onRated: (id) {
                            setState(() => _locallyRated.add(id));
                            // Also clear the feed's recap banner for this hang.
                            context.read<FeedController>().markRated(id);
                          },
                        )
                      : _activityTile(context, a, uid, l),
              ],
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _activityTile(
      BuildContext context, Activity a, String? uid, AppLocalizations l) {
    final hosting = a.hostId == uid;
    // A chat exists once the activity has at least 2 members.
    final hasChat = a.memberIds.length >= 2;

    Future<void> openChat() async {
      context.read<AnalyticsService>().buttonClicked(
        'open_chat',
        params: {'activity_id': a.id},
      );
      // Self-heal: make sure the chat exists and lists all current activity
      // members before opening — fixes legacy/hand-seeded activities whose chat
      // doc is out of sync (which otherwise yields a permission-denied stream).
      final navigator = Navigator.of(context);
      try {
        await context.read<ChatRepository>().syncChatMembers(
              a.id,
              title: a.title,
              memberIds: a.memberIds,
            );
      } catch (_) {/* best-effort; open anyway */}
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(chatId: a.id, title: a.title, activity: a),
        ),
      );
    }

    void openDetails() {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ActivityDetailsScreen(activityId: a.id, initialActivity: a),
      ));
    }

    // Trailing shows the Hosting chip when relevant AND a chat affordance
    // whenever a chat exists — so a host can always reach the group chat.
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hosting)
          Chip(
            label: Text(l.tr('myActivities.hosting')),
            visualDensity: VisualDensity.compact,
          ),
        if (hasChat)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: l.tr('chat.title'),
            onPressed: openChat,
          ),
      ],
    );

    return ListTile(
      leading: CircleAvatar(child: Text(a.category.emoji)),
      title: Text(a.title),
      subtitle: Text(a.placeSuggestion),
      trailing: trailing,
      // Tapping the row opens the activity details (members, chat shortcut…).
      onTap: openDetails,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Text(text,
            style: Theme.of(context).textTheme.titleMedium),
      );
}
