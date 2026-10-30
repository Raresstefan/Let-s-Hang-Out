import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../activity_details/activity_details_screen.dart';
import '../post_hang/recap_banner.dart';
import '../profile/profile_avatar_button.dart';
import 'feed_controller.dart';
import 'widgets/activity_card.dart';
import 'widgets/city_filter.dart';
import 'widgets/emoji_filter_bar.dart';

/// The Discover feed: emoji filter bar on top, scrollable list of activity cards.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Recap banners dismissed this session (by activity id) so they don't reappear
  // until the next launch (a rated activity drops out permanently anyway).
  final Set<String> _dismissedRecaps = {};

  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    context.read<AnalyticsService>().inputTyping('search_activities');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<FeedController>().setQuery(value);
    });
  }

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo/app_icon.png',
                width: 36,
                height: 36,
              ),
            ),
            const SizedBox(width: 10),
            Column(
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
          ],
        ),
        actions: const [ProfileAvatarButton()],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.tr('feed.searchHint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            context.read<FeedController>().setQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (controller.city != null ||
                controller.cityOptions.isNotEmpty)
              CityFilterChip(
                selected: controller.city,
                options: controller.cityOptions,
                totalCount: controller.discoverableCount,
                onChanged: controller.setCity,
              ),
            EmojiFilterBar(
              active: controller.activeFilter,
              onSelected: controller.toggleFilter,
              onClear: controller.clearFilter,
              onMoreOpened: () =>
                  analytics.buttonClicked('open_feed_category_picker'),
            ),
            if (controller.recapCandidate != null &&
                !_dismissedRecaps.contains(controller.recapCandidate!.id))
              RecapBanner(
                activity: controller.recapCandidate!,
                onDismiss: () => setState(() =>
                    _dismissedRecaps.add(controller.recapCandidate!.id)),
                onRated: controller.markRated,
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
    final visible = controller.visibleActivities;
    if (visible.isEmpty) {
      // Either nothing matches the active filter / search, or everything
      // loaded has since started.
      final filtering = controller.activeFilter != null ||
          controller.city != null ||
          controller.query.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.city != null
                    ? l.tr('feed.city.empty', {'city': controller.city!})
                    : l.tr(filtering ? 'feed.noMatches' : 'feed.empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (controller.city != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => controller.setCity(null),
                  child: Text(l.tr('feed.city.showAll')),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final activity = visible[i];
        return ActivityCard(
          activity: activity,
          analytics: analytics,
          friendsGoing: controller.friendsGoing(activity),
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
