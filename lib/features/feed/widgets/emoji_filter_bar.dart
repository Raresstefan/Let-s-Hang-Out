import 'package:flutter/material.dart';

import '../../../domain/models/activity_category.dart';

/// Horizontal row of emoji filter buttons. Tapping one filters the feed to that
/// category; tapping the active one again clears the filter.
class EmojiFilterBar extends StatelessWidget {
  const EmojiFilterBar({
    super.key,
    required this.active,
    required this.onSelected,
  });

  final ActivityCategory? active;
  final ValueChanged<ActivityCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: ActivityCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = ActivityCategory.values[i];
          final selected = category == active;
          return GestureDetector(
            onTap: () => onSelected(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black12,
                ),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}
