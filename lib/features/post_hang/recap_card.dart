import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/activity.dart';
import 'recap_sheet.dart';

/// An inline "How was {title}?" card shown for an un-recapped past activity in
/// the My Activities → Past section. Tap → recap sheet.
class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.activity, this.onRated});

  final Activity activity;

  /// Called with the activity id when the user rates it in the sheet, so the
  /// list can drop this card immediately (no refetch race).
  final void Function(String activityId)? onRated;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.seed.withValues(alpha: 0.14),
            AppTheme.peach.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.seed.withValues(alpha: 0.22)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Text(activity.category.emoji,
            style: const TextStyle(fontSize: 26)),
        title: Text(
          l.tr('postHang.recapPrompt', {'title': activity.title}),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(l.tr('postHang.rateLabel'),
            style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.star_rounded, color: AppTheme.seed),
        onTap: () async {
          final rated = await RecapSheet.show(context, activity);
          if (rated) onRated?.call(activity.id);
        },
      ),
    );
  }
}
