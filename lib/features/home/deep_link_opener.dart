import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/links/deep_link_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../activity_details/activity_details_screen.dart';

/// Opens the activity from a shared link once the user is signed in and past
/// the Terms gate (it wraps the home shell).
class DeepLinkOpener extends StatefulWidget {
  const DeepLinkOpener({super.key, required this.child});

  final Widget child;

  @override
  State<DeepLinkOpener> createState() => _DeepLinkOpenerState();
}

class _DeepLinkOpenerState extends State<DeepLinkOpener> {
  late final DeepLinkService _links = context.read<DeepLinkService>();

  @override
  void initState() {
    super.initState();
    _links.addListener(_onLink);
    // A link that arrived before sign-in is waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLink());
  }

  @override
  void dispose() {
    _links.removeListener(_onLink);
    super.dispose();
  }

  Future<void> _onLink() async {
    if (!mounted) return;
    final id = _links.take();
    if (id == null) return;
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    context
        .read<AnalyticsService>()
        .logEvent('activity_link_opened', params: {'activity_id': id});
    final activity = await context
        .read<ActivityRepository>()
        .fetchActivity(id)
        .catchError((Object _) => null);
    if (!mounted) return;
    if (activity == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('activity.link.unavailable'))),
      );
      return;
    }
    navigator.push(MaterialPageRoute(
      builder: (_) => ActivityDetailsScreen(
        activityId: activity.id,
        initialActivity: activity,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
