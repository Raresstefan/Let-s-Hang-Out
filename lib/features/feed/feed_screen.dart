import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../activity_details/activity_details_screen.dart';
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

    // Surface a transient action error (e.g. an offline like) once, as a snackbar.
    final actionError = controller.consumeActionError();
    if (actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tr('common.error.$actionError'))),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.tr('feed.title'),
                style: Theme.of(context).textTheme.headlineMedium),
            Text(
              l.tr('feed.subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: Column(
          children: [
            EmojiFilterBar(
              active: controller.activeFilter,
              onSelected: controller.toggleFilter,
              onClear: controller.clearFilter,
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
          onLike: () => controller.toggleLike(activity),
          onOpen: () {
            analytics.buttonClicked('open_activity',
                params: {'activity_id': activity.id});
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ActivityDetailsScreen(activityId: activity.id),
            ));
          },
        );
      },
    );
  }
}
