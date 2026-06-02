import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/analytics/analytics_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/repositories/mock_activity_repository.dart';
import '../../../domain/models/activity.dart';

/// A single activity rendered as an image-forward Card: full-bleed cover with a
/// gradient scrim, glass chips, the title/time/place laid over the photo, and a
/// gradient "Join" pill. Fires `Hang:${title}:OnLoad` once.
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
    final catColor = CategoryStyle.color(a.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.softShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Image-forward hero ----
          SizedBox(
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                a.coverImageUrl != null
                    ? CoverImage(source: a.coverImageUrl!)
                    : DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: CategoryStyle.gradient(a.category)),
                        child: Center(
                          child: Text(a.category.emoji,
                              style: const TextStyle(fontSize: 56)),
                        ),
                      ),
                // Bottom scrim so overlaid text is legible.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87, Colors.black87],
                      stops: [0.4, 0.92, 1.0],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                // Top row of glass chips.
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _CategoryChip(
                        emoji: a.category.emoji,
                        label: l.tr('feed.filters.${a.category.id}'),
                        color: catColor,
                      ),
                      const Spacer(),
                      if (a.isSuggested && a.likeCount > 0)
                        _GlassChip(
                          icon: Icons.favorite,
                          label: l.tr('feed.likedCount', {'count': a.likeCount}),
                        ),
                    ],
                  ),
                ),
                // Overlaid title + meta.
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _MetaRow(
                        startAt: a.startAt,
                        place: a.placeSuggestion,
                        enrolled: l.tr(
                            'activity.enrolledCount', {'count': a.enrolledCount}),
                        l: l,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ---- Footer: Join CTA ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _JoinButton(
              joined: joined,
              onJoin: widget.onJoin,
              joinLabel: l.tr('common.join'),
              joinedLabel: l.tr('common.joined'),
            ),
          ),
        ],
      ),
    );
  }
}

/// White-on-photo meta row: time · place, plus an enrolled count.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.startAt,
    required this.place,
    required this.enrolled,
    required this.l,
  });

  final DateTime startAt;
  final String place;
  final String enrolled;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    const white70 = Color(0xB3FFFFFF);
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: white70, fontWeight: FontWeight.w500);
    return Row(
      children: [
        const Icon(Icons.schedule, size: 15, color: white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l.tr('activity.startsIn',
                {'when': timeago.format(startAt, allowFromNow: true)}),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.place_outlined, size: 15, color: white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(place,
              style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.people_alt_rounded, size: 15, color: white70),
        const SizedBox(width: 4),
        Text(enrolled, style: style),
      ],
    );
  }
}

/// Gradient pill Join button; tonal "Joined" state when already a member.
class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.joined,
    required this.onJoin,
    required this.joinLabel,
    required this.joinedLabel,
  });

  final bool joined;
  final VoidCallback onJoin;
  final String joinLabel;
  final String joinedLabel;

  @override
  Widget build(BuildContext context) {
    if (joined) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 20, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(joinedLabel,
                style: const TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onJoin,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppTheme.seed.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 6),
                Text(joinLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted-glass chip (blurred translucent background, thin white border).
class _GlassChip extends StatelessWidget {
  const _GlassChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category chip with a colored dot + label, on the glass background.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('$emoji $label',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
