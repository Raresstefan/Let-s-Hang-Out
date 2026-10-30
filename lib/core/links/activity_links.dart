/// Shareable links to activities.
///
/// Shared links are web URLs on the project's free Firebase Hosting domain
/// (`hosting/public`): with the app installed they open it straight on the
/// activity (Android App Links); otherwise the landing page offers "Open in
/// the app" and the store buttons. `hangout://activity/<id>` is the custom
/// scheme the landing page uses to hand over to the app.
class ActivityLinks {
  ActivityLinks._();

  static const host = 'hang-out-129b5.web.app';
  static const _altHost = 'hang-out-129b5.firebaseapp.com';
  static const scheme = 'hangout';

  static String url(String activityId) =>
      'https://$host/a/${Uri.encodeComponent(activityId)}';

  /// The activity id in [uri], or null when it isn't an activity link.
  static String? activityId(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? id;
    if (uri.scheme == 'https' &&
        (uri.host == host || uri.host == _altHost) &&
        segments.length == 2 &&
        segments.first == 'a') {
      id = segments[1];
    } else if (uri.scheme == scheme &&
        uri.host == 'activity' &&
        segments.length == 1) {
      id = segments.single;
    }
    if (id == null || !_validId.hasMatch(id)) return null;
    return id;
  }

  // Firestore auto-ids and the mock ids ("act-beers").
  static final _validId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
}
