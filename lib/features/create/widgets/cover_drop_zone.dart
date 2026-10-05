import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../core/widgets/image_pick.dart';
import '../../../domain/models/activity_category.dart';

/// Compact optional cover picker. The category visual remains the default,
/// while desktop users can still drop a photo anywhere on this control.
class CoverDropZone extends StatefulWidget {
  const CoverDropZone({
    super.key,
    required this.category,
    required this.onChanged,
  });

  final ActivityCategory category;
  final ValueChanged<PickedImage?> onChanged;

  @override
  State<CoverDropZone> createState() => _CoverDropZoneState();
}

class _CoverDropZoneState extends State<CoverDropZone> {
  bool _dragging = false;
  PickedImage? _picked;

  void _apply(PickedImage? picked) {
    if (picked == null) return;
    if (!picked.ok) {
      _showError(picked.error);
      return;
    }
    setState(() => _picked = picked);
    widget.onChanged(picked);
  }

  void _clear() {
    setState(() => _picked = null);
    widget.onChanged(null);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    _apply(await PickedImage.fromDrop(details));
  }

  Future<void> _browse() async {
    _apply(await PickedImage.browse());
  }

  void _showError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Please choose a .png or .jpg image')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _handleDrop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _dragging
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _dragging ? scheme.primary : scheme.outlineVariant,
            width: _dragging ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _picked != null
                      ? CoverImage(source: _picked!.dataUrl!)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: CategoryStyle.gradient(widget.category),
                          ),
                          child: Center(
                            child: Text(
                              widget.category.emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _picked?.fileName ??
                        l.tr('activity.create.categoryCover', {
                          'category': widget.category.label,
                        }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _picked == null
                        ? l.tr('activity.create.coverFallback')
                        : l.tr('activity.create.coverSelected'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _browse,
                        icon: Icon(
                          _picked == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.swap_horiz,
                          size: 18,
                        ),
                        label: Text(
                          l.tr(
                            _picked == null
                                ? 'activity.create.coverAdd'
                                : 'activity.create.coverReplace',
                          ),
                        ),
                      ),
                      if (_picked != null)
                        TextButton(
                          onPressed: _clear,
                          child: Text(l.tr('activity.create.coverRemove')),
                        ),
                    ],
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
