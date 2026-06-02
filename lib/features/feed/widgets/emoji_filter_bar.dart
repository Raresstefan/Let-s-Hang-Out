import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/category_style.dart';
import '../../../domain/models/activity_category.dart';

/// Horizontal row of category filter pills (emoji + label). Tapping one filters
/// the feed to that category; the active one shows its category color. A leading
/// "All" pill clears the filter. Tapping the active pill again also clears it.
class EmojiFilterBar extends StatelessWidget {
  const EmojiFilterBar({
    super.key,
    required this.active,
    required this.onSelected,
    required this.onClear,
  });

  final ActivityCategory? active;
  final ValueChanged<ActivityCategory> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _Pill(
            label: l.tr('feed.filters.all'),
            selected: active == null,
            color: Theme.of(context).colorScheme.primary,
            onTap: onClear,
          ),
          const SizedBox(width: 8),
          for (final category in ActivityCategory.values) ...[
            _Pill(
              emoji: category.emoji,
              label: l.tr('feed.filters.${category.id}'),
              selected: category == active,
              color: CategoryStyle.color(category),
              onTap: () => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.emoji,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String? emoji;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF44403C),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
