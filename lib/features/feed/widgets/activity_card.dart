import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/analytics/analytics_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/repositories/mock_activity_repository.dart';
import '../../../domain/models/activity.dart';

/// A single activity rendered as a Card: cover image background, title, and the
/// current number of people enrolled. Fires `Hang:${title}:OnLoad` once.
class ActivityCard extends StatefulWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.analytics,
    required this.onJoin,
  });

  final Activity activity;
  final AnalyticsService analytics;
  final VoidCallback onJoin;

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  @override
  void initState() {
    super.initState();
    // OnLoad event — deduped inside the analytics service.
    widget.analytics
        .activityOnLoad(widget.activity.title, activityId: widget.activity.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = widget.activity;
    final joined = a.isMember(MockActivityRepository.currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: a.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: a.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.black12),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: Colors.black12),
                      )
                    : ColoredBox(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Center(
                          child: Text(a.category.emoji,
                              style: const TextStyle(fontSize: 48)),
                        ),
                      ),
              ),
              if (a.isSuggested)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Chip(
                    icon: Icons.favorite,
                    label: l.tr('feed.suggestedBanner'),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: _Chip(
                  label:
                      '${a.category.emoji}  ${l.tr('activity.enrolledCount', {'count': a.enrolledCount})}',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 4),
                    Text(l.tr('activity.startsIn',
                        {'when': timeago.format(a.startAt, allowFromNow: true)})),
                    const SizedBox(width: 12),
                    const Icon(Icons.place_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(a.placeSuggestion,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: joined ? null : widget.onJoin,
                    icon: Icon(joined ? Icons.check : Icons.add),
                    label: Text(
                        joined ? l.tr('common.joined') : l.tr('common.join')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
