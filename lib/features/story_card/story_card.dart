import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/links/activity_links.dart';
import '../../core/theme/category_style.dart';
import '../../core/widgets/cover_image.dart';
import '../../domain/models/activity.dart';

enum StoryCardStyle { photo, color, dark }

/// Who is sharing, which picks the headline.
enum StoryRole { host, going, invite }

/// A 9:16 story image ("I'm going to…") for Instagram / WhatsApp Status.
/// Laid out at [size] logical pixels and captured at 3x, giving 1080x1920.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.activity,
    required this.style,
    required this.role,
    this.initials = const [],
  });

  static const size = Size(360, 640);

  final Activity activity;
  final StoryCardStyle style;
  final StoryRole role;

  /// Initials of a few people going (never full names).
  final List<String> initials;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = activity;
    final cat = CategoryStyle.color(a.category);
    final ml = MaterialLocalizations.of(context);
    final time = ml.formatTimeOfDay(TimeOfDay.fromDateTime(a.startAt),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    final when = '${ml.formatMediumDate(a.startAt)} · $time';
    final headline = l.tr(switch (role) {
      StoryRole.host => 'storyCard.hosting',
      StoryRole.going => 'storyCard.going',
      StoryRole.invite => 'storyCard.invite',
    });
    final titleSize = a.title.length > 40
        ? 26.0
        : a.title.length > 22
            ? 32.0
            : 38.0;
    const white = Colors.white;
    final onColor = style == StoryCardStyle.color;

    return SizedBox.fromSize(
      size: size,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _background(a, cat),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset('assets/logo/app_icon.png',
                            width: 30, height: 30),
                      ),
                      const SizedBox(width: 8),
                      const Text('Hang Out',
                          style: TextStyle(
                              color: white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(flex: 3),
                  Text(a.category.emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: onColor ? white : cat,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      headline.toUpperCase(),
                      style: TextStyle(
                        color: onColor ? cat : white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    a.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: white,
                      fontSize: titleSize,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(blurRadius: 12, color: Colors.black38)
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _InfoRow(icon: Icons.event_rounded, text: when),
                  if (a.placeWithCity.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.place_rounded, text: a.placeWithCity),
                  ],
                  const SizedBox(height: 14),
                  _GoingRow(
                    initials: initials,
                    label: l.tr(
                        'storyCard.goingCount', {'count': a.enrolledCount}),
                    accent: cat,
                  ),
                  const Spacer(flex: 2),
                  _JoinPanel(activityId: a.id, accent: cat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background(Activity a, Color cat) {
    switch (style) {
      case StoryCardStyle.photo:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (a.coverImageUrl != null && a.coverImageUrl!.isNotEmpty)
              CoverImage(source: a.coverImageUrl!)
            else
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: CategoryStyle.gradient(a.category))),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.black54, Colors.black87],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ],
        );
      case StoryCardStyle.color:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(cat, Colors.white, 0.12)!,
                cat,
                Color.lerp(cat, Colors.black, 0.35)!,
              ],
            ),
          ),
        );
      case StoryCardStyle.dark:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, -0.7),
              radius: 1.2,
              colors: [cat.withValues(alpha: 0.55), const Color(0xFF14121A)],
            ),
          ),
        );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}

class _GoingRow extends StatelessWidget {
  const _GoingRow(
      {required this.initials, required this.label, required this.accent});

  final List<String> initials;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final shown = initials.take(4).toList();
    return Row(
      children: [
        if (shown.isNotEmpty) ...[
          SizedBox(
            width: 28.0 + (shown.length - 1) * 20,
            height: 28,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color.lerp(accent, Colors.black, i * 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(shown[i],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// White panel with the QR + short link. Instagram doesn't let apps attach a
/// tappable link, so the QR and the printed link are how viewers join.
class _JoinPanel extends StatelessWidget {
  const _JoinPanel({required this.activityId, required this.accent});

  final String activityId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final url = ActivityLinks.url(activityId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          QrImageView(
            data: url,
            size: 84,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.tr('storyCard.joinMe'),
                    style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(l.tr('storyCard.scan'),
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  url.replaceFirst('https://', ''),
                  maxLines: 2,
                  style: const TextStyle(color: Colors.black54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials for the card, e.g. "Ana Pop" → "AP", "mihai" → "M".
String initialsOf(String displayName) {
  final parts =
      displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}
