import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/analytics/analytics_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/auth/auth_service.dart';
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
    required this.onLike,
    required this.onOpen,
    this.friendsGoing = 0,
  });

  final Activity activity;
  final AnalyticsService analytics;
  final VoidCallback onJoin;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  /// Number of the viewer's friends enrolled — shows a social-proof badge.
  final int friendsGoing;

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
    final uid = context.watch<AuthService>().currentUserId;
    final joined = uid != null && a.isMember(uid);
    final liked = uid != null && a.isLikedBy(uid);
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
          // ---- Image-forward hero (tap to open details) ----
          GestureDetector(
            onTap: widget.onOpen,
            child: SizedBox(
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
                      _LikeChip(
                        liked: liked,
                        count: a.likeCount,
                        onTap: widget.onLike,
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
          ),
          // ---- Footer: friends-going social proof + Join CTA ----
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.friendsGoing > 0) ...[
                  _FriendsGoingBadge(
                    label: l.tr(
                        'friends.friendsGoing', {'count': widget.friendsGoing}),
                  ),
                  const SizedBox(height: 10),
                ],
                _JoinButton(
                  joined: joined,
                  onJoin: widget.onJoin,
                  joinLabel: l.tr('common.join'),
                  joinedLabel: l.tr('common.joined'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Social-proof pill: "N friends going". Tinted accent so it draws the eye.
class _FriendsGoingBadge extends StatelessWidget {
  const _FriendsGoingBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_rounded, size: 15, color: AppTheme.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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

/// Tappable frosted-glass like pill: heart + count. Filled coral heart when the
/// current user has liked it, outlined white otherwise. Shown on every card.
class _LikeChip extends StatelessWidget {
  const _LikeChip({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: liked ? AppTheme.seed : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
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
