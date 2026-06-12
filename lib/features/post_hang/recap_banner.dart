import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import 'recap_sheet.dart';

/// A dismissible "How was {title}?" banner for a recently-ended, un-recapped
/// activity. Used at the top of the Discover feed.
class RecapBanner extends StatelessWidget {
  const RecapBanner({
    super.key,
    required this.activity,
    required this.onDismiss,
    this.onRated,
  });

  final Activity activity;
  final VoidCallback onDismiss;

  /// Called with the activity id when the user rates it from the banner.
  final void Function(String activityId)? onRated;

  Future<void> _openRecap(BuildContext context) async {
    final rated = await RecapSheet.show(context, activity);
    if (rated) onRated?.call(activity.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.seed.withValues(alpha: 0.16),
            AppTheme.peach.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.seed.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openRecap(context),
              child: Text(
                l.tr('postHang.recapPrompt', {'title': activity.title}),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => _openRecap(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.tr('postHang.rateLabel')),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: l.tr('postHang.dismiss'),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
