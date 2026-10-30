import 'package:flutter/widgets.dart';

/// Where the share sheet should point, in global coordinates. On iPad the iOS
/// share sheet is a popover anchored to this rect, and share_plus refuses to
/// share without one. Pass the tapped button's own context; falls back to a
/// point in the middle of the screen if it can't be measured.
Rect shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
}
