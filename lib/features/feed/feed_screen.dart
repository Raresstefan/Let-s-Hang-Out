import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import 'feed_controller.dart';
import 'widgets/activity_card.dart';
import 'widgets/emoji_filter_bar.dart';

/// The Discover feed: emoji filter bar on top, scrollable list of activity cards.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<FeedController>();
    final analytics = context.read<AnalyticsService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('feed.title'),
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: Column(
          children: [
            EmojiFilterBar(
              active: controller.activeFilter,
              onSelected: controller.toggleFilter,
            ),
            Expanded(child: _buildBody(context, l, controller, analytics)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l,
      FeedController controller, AnalyticsService analytics) {
    if (controller.loading && controller.activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.tr('common.error.generic')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: controller.load, child: Text(l.tr('common.retry'))),
          ],
        ),
      );
    }
    if (controller.activities.isEmpty) {
      return Center(child: Text(l.tr('feed.empty')));
    }
    return ListView.builder(
      itemCount: controller.activities.length,
      itemBuilder: (context, i) {
        final activity = controller.activities[i];
        return ActivityCard(
          activity: activity,
          analytics: analytics,
          onJoin: () => controller.join(activity),
        );
      },
    );
  }
}
