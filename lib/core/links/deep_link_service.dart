import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'activity_links.dart';

/// Receives activity links that opened the app (cold start or while running)
/// and holds the latest one until the signed-in home screen takes it, so a
/// link survives sign-in and the Terms gate.
class DeepLinkService extends ChangeNotifier {
  DeepLinkService(Stream<Uri> links) {
    _sub = links.listen(_onLink, onError: (Object _) {});
  }

  /// Listens to the platform's incoming links (includes the cold-start link).
  factory DeepLinkService.platform() =>
      DeepLinkService(AppLinks().uriLinkStream);

  /// No links (tests, web demo).
  factory DeepLinkService.none() => DeepLinkService(const Stream.empty());

  late final StreamSubscription<Uri> _sub;
  String? _pendingActivityId;

  String? get pendingActivityId => _pendingActivityId;

  /// Returns and clears the pending activity id.
  String? take() {
    final id = _pendingActivityId;
    _pendingActivityId = null;
    return id;
  }

  void _onLink(Uri uri) {
    final id = ActivityLinks.activityId(uri);
    if (id != null) openActivity(id);
  }

  /// Queues [activityId] to be opened (e.g. from a tapped reminder).
  void openActivity(String activityId) {
    _pendingActivityId = activityId;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
