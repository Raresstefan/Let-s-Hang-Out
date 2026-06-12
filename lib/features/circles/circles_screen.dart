import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/circle.dart';
import '../profile/profile_avatar_button.dart';
import 'circle_detail_screen.dart';
import 'circles_controller.dart';
import 'create_circle_sheet.dart';

/// The Circles tab: pending circle invites (Accept/Deny), your circles, and a
/// "+ New circle" action.
class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

  Future<void> _newCircle(BuildContext context) async {
    context.read<AnalyticsService>().buttonClicked('open_create_circle');
    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateCircleSheet(),
    );
  }

  void _openCircle(BuildContext context, Circle circle) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CircleDetailScreen(circleId: circle.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.watch<CirclesController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('circles.title')),
        actions: const [ProfileAvatarButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newCircle(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.tr('circles.create')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // ---- Invites ----
          if (c.incoming.isNotEmpty) ...[
            _SectionHeader(l.tr('circles.invitesTitle')),
            for (final e in c.incoming)
              _InviteTile(
                emoji: '👥',
                title: e.fromUser.displayName.trim().isNotEmpty
                    ? e.fromUser.displayName
                    : l.tr('userProfile.unknown'),
                subtitle:
                    l.tr('circles.invitedYou', {'circle': e.invite.circleName}),
                onAccept: () => context.read<CirclesController>().accept(e),
                onDeny: () => context.read<CirclesController>().decline(e),
                acceptLabel: l.tr('circles.accept'),
                denyLabel: l.tr('circles.deny'),
              ),
            const SizedBox(height: 16),
          ],

          // ---- Your circles ----
          if (c.myCircles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  l.tr('circles.empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final circle in c.myCircles)
              _CircleTile(
                circle: circle,
                memberCountLabel: l.tr(
                    'circles.memberCount', {'count': circle.memberCount}),
                onTap: () => _openCircle(context, circle),
              ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _CircleTile extends StatelessWidget {
  const _CircleTile({
    required this.circle,
    required this.memberCountLabel,
    required this.onTap,
  });

  final Circle circle;
  final String memberCountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.softShadow(opacity: 0.06, blur: 14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.seed.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(circle.emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(circle.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(memberCountLabel),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onAccept,
    required this.onDeny,
    required this.acceptLabel,
    required this.denyLabel,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onAccept;
  final VoidCallback onDeny;
  final String acceptLabel;
  final String denyLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
        child: Text(emoji),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(acceptLabel),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onDeny,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(denyLabel),
          ),
        ],
      ),
    );
  }
}
