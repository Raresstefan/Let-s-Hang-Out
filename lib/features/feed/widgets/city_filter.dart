import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../domain/models/city_names.dart';

/// "📍 All cities ▾" chip above the feed. Opens a sheet listing only the
/// cities that currently have activities, with how many each has.
class CityFilterChip extends StatelessWidget {
  const CityFilterChip({
    super.key,
    required this.selected,
    required this.options,
    required this.totalCount,
    required this.onChanged,
  });

  final String? selected;
  final List<CityOption> options;

  /// Sum of the per-city counts, shown next to "All cities".
  final int totalCount;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = selected != null;
    final key = active ? cityKey(selected!) : null;
    final label = active
        ? options
            .firstWhere((o) => o.key == key,
                orElse: () => CityOption(selected!, 0))
            .name
        : l.tr('feed.city.all');
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: InputChip(
          key: const Key('city_filter_chip'),
          avatar: const Icon(Icons.place_outlined, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (!active) const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
          selected: active,
          showCheckmark: false,
          onPressed: () async {
            final picked = await showCityPicker(context,
                selected: selected, options: options, totalCount: totalCount);
            if (picked != null) onChanged(picked.isEmpty ? null : picked);
          },
          onDeleted: active ? () => onChanged(null) : null,
        ),
      ),
    );
  }
}

/// Returns the picked city, '' for "All cities", or null when dismissed.
Future<String?> showCityPicker(
  BuildContext context, {
  required String? selected,
  required List<CityOption> options,
  required int totalCount,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _CityPickerSheet(
            selected: selected, options: options, totalCount: totalCount),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.selected,
    required this.options,
    required this.totalCount,
  });

  final String? selected;
  final List<CityOption> options;
  final int totalCount;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedKey =
        widget.selected == null ? null : cityKey(widget.selected!);
    final options = [...widget.options];
    // Keep a remembered city visible even if nothing is on there right now.
    if (selectedKey != null && !options.any((o) => o.key == selectedKey)) {
      options.add(CityOption(widget.selected!, 0));
    }
    final q = cityKey(_query);
    final shown = q.isEmpty
        ? options
        : options.where((o) => o.key.contains(q)).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.tr('feed.city.title'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (options.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.tr('feed.city.search'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (q.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.public),
                      title: Text(l.tr('feed.city.all')),
                      trailing: Text('${widget.totalCount}'),
                      selected: selectedKey == null,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                  for (final o in shown)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(o.name),
                      trailing: Text('${o.count}'),
                      selected: o.key == selectedKey,
                      onTap: () => Navigator.of(context).pop(o.name),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.tr('feed.city.noMatches'),
                          textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
