import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/category_style.dart';
import '../../domain/models/activity_category.dart';

Future<ActivityCategory?> showActivityCategoryPicker(
  BuildContext context, {
  ActivityCategory? selected,
}) {
  return showModalBottomSheet<ActivityCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ActivityCategoryPicker(selected: selected),
  );
}

class ActivityCategoryPicker extends StatefulWidget {
  const ActivityCategoryPicker({super.key, this.selected});

  final ActivityCategory? selected;

  @override
  State<ActivityCategoryPicker> createState() => _ActivityCategoryPickerState();
}

class _ActivityCategoryPickerState extends State<ActivityCategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = _filteredGroups();

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tr('activity.categoryPicker.title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: false,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: l.tr('activity.categoryPicker.searchHint'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(child: Text(l.tr('activity.categoryPicker.empty')))
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        for (final group in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                            child: Text(
                              group.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          for (final category in group.categories)
                            _CategoryTile(
                              category: category,
                              selected: category == widget.selected,
                              onTap: () => Navigator.of(context).pop(category),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<ActivityCategoryGroup> _filteredGroups() {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return ActivityCategory.groups;
    return [
      for (final group in ActivityCategory.groups)
        if (group.categories.any((category) => _matches(category, query)))
          ActivityCategoryGroup(
            group.label,
            group.categories
                .where((category) => _matches(category, query))
                .toList(),
          ),
    ];
  }

  bool _matches(ActivityCategory category, String query) =>
      category.label.toLowerCase().contains(query) ||
      category.id.replaceAll('_', ' ').contains(query);
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ActivityCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(category);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Text(category.emoji),
      ),
      title: Text(category.label),
      trailing: selected
          ? Icon(Icons.check_circle, color: color)
          : const Icon(Icons.chevron_right),
    );
  }
}
