import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/cover_image.dart';
import '../../../core/widgets/image_pick.dart';

/// A drag & drop box for the activity cover image. Users can drop a .png/.jpg
/// file onto it or click to browse. On selection it shows a preview and reports
/// a `data:` URL via [onChanged] (which flows through the existing
/// `coverImageUrl` String field). Pass null to [onChanged] when cleared.
class CoverDropZone extends StatefulWidget {
  const CoverDropZone({
    super.key,
    required this.onChanged,
    this.hint,
  });

  final ValueChanged<String?> onChanged;
  final String? hint;

  @override
  State<CoverDropZone> createState() => _CoverDropZoneState();
}

class _CoverDropZoneState extends State<CoverDropZone> {
  bool _dragging = false;
  String? _dataUrl; // current preview source
  String? _fileName;

  bool _hasImage = false;

  void _apply(PickedImage? picked) {
    if (picked == null) return; // cancelled
    if (!picked.ok) {
      _showError(message: picked.error);
      return;
    }
    setState(() {
      _dataUrl = picked.dataUrl;
      _fileName = picked.fileName;
      _hasImage = true;
    });
    widget.onChanged(picked.dataUrl);
  }

  void _clear() {
    setState(() {
      _dataUrl = null;
      _fileName = null;
      _hasImage = false;
    });
    widget.onChanged(null);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    _apply(await PickedImage.fromDrop(details));
  }

  Future<void> _browse() async {
    _apply(await PickedImage.browse());
  }

  void _showError({String? message}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Please choose a .png or .jpg image')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = _dragging ? scheme.primary : scheme.outlineVariant;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _handleDrop,
      // Centre a card-shaped (16:9) frame so the preview matches how covers
      // appear on the activity cards, instead of a wide, stretched strip.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: InkWell(
            onTap: _browse,
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: _dragging
                      ? scheme.primary.withValues(alpha: 0.06)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: _dragging ? 2 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _hasImage ? _preview(scheme) : _empty(scheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 40, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            widget.hint ?? 'Drag & drop an image here',
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'or click to browse · PNG, JPG',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverImage(source: _dataUrl!),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Remove image',
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: _clear,
            ),
          ),
        ),
        if (_fileName != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _fileName!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}
