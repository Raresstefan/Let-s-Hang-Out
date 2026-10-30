import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../core/widgets/image_pick.dart';

/// A circular drag & drop profile-avatar picker. Drop a .png/.jpg onto it or tap
/// to browse. When empty it shows [initial] on a brand-tinted circle; a small
/// camera badge always signals it's editable. Reports a `data:` URL via
/// [onChanged] (null is never sent — the avatar can only be replaced, not
/// cleared, from here).
class AvatarDropZone extends StatefulWidget {
  const AvatarDropZone({
    super.key,
    required this.initial,
    required this.dataUrl,
    required this.onChanged,
    this.size = 112,
  });

  /// Letter shown when there's no image (e.g. the name's first character).
  final String initial;

  /// Current avatar source (data/network URL), or null when none set.
  final String? dataUrl;

  final ValueChanged<String> onChanged;
  final double size;

  @override
  State<AvatarDropZone> createState() => _AvatarDropZoneState();
}

class _AvatarDropZoneState extends State<AvatarDropZone> {
  bool _dragging = false;

  Future<void> _apply(PickedImage? picked) async {
    if (picked == null) return; // cancelled
    if (!picked.ok) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(picked.error!)));
      }
      return;
    }
    try {
      final url = await avatarDataUrl(picked.bytes!);
      if (mounted) widget.onChanged(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).tr('profile.photoFailed'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    final hasImage = widget.dataUrl != null;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) async {
        setState(() => _dragging = false);
        _apply(await PickedImage.fromDrop(d));
      },
      child: InkWell(
        onTap: () async => _apply(await PickedImage.browse()),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The circle (image or initial).
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasImage ? null : AppTheme.brandGradient,
                  boxShadow: AppTheme.softShadow(opacity: 0.18, blur: 18),
                  border: Border.all(
                    color: _dragging ? scheme.primary : Colors.white,
                    width: _dragging ? 3 : 4,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? CoverImage(source: widget.dataUrl!)
                    : Center(
                        child: Text(
                          widget.initial,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              // Camera badge (always visible — affordance to change photo).
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
