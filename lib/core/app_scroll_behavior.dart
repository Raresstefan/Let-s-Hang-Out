import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide scroll behavior.
///
/// Keeps the platform's native scroll physics (so it feels right on each
/// platform) and only broadens the accepted drag devices so horizontal lists
/// (e.g. the emoji filter bar) can also be dragged with a mouse/trackpad on
/// web & desktop — not just flicked. Touch scrolling on a phone is unchanged.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
