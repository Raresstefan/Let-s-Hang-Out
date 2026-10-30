import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';

/// A maps app the user can open an activity's place in.
enum MapApp { googleMaps, appleMaps, waze, otherApps }

/// Free, key-less deep links that search the place text in each maps app.
/// [native] opens the installed app directly; [web] is the fallback that works
/// without the app (and on Android/iOS hands off to the app when installed).
class MapLink {
  const MapLink(this.app, {required this.web, this.native});

  final MapApp app;
  final Uri web;
  final Uri? native;

  static MapLink forPlace(MapApp app, String place) {
    final q = Uri.encodeComponent(place.trim());
    switch (app) {
      case MapApp.googleMaps:
        return MapLink(
          app,
          web: Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
          native: Uri.parse('comgooglemaps://?q=$q'),
        );
      case MapApp.appleMaps:
        return MapLink(app, web: Uri.parse('https://maps.apple.com/?q=$q'));
      case MapApp.waze:
        return MapLink(
          app,
          web: Uri.parse('https://waze.com/ul?q=$q&navigate=yes'),
          native: Uri.parse('waze://?q=$q&navigate=yes'),
        );
      case MapApp.otherApps:
        // Android's generic map intent: shows a chooser of every installed
        // maps app (OsmAnd, HERE, Maps.me, …).
        return MapLink(app, web: Uri.parse('geo:0,0?q=$q'));
    }
  }
}

/// Opens a sheet listing the maps apps available on this device plus "Copy
/// address"; tapping one opens [place] in that app.
Future<void> showDirectionsSheet(
  BuildContext context, {
  required String place,
  required String activityId,
}) async {
  final l = AppLocalizations.of(context);
  final analytics = context.read<AnalyticsService>();
  analytics.buttonClicked('get_directions', params: {'activity_id': activityId});

  final apps = await _availableApps(place);
  if (!context.mounted) return;

  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              place,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          for (final link in apps)
            ListTile(
              leading: Icon(_icon(link.app)),
              title: Text(l.tr(_labelKey(link.app))),
              onTap: () => Navigator.of(ctx).pop(link),
            ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(l.tr('activity.detail.directions.copy')),
            onTap: () => Navigator.of(ctx).pop('copy'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  final messenger = ScaffoldMessenger.of(context);

  if (choice == 'copy') {
    await Clipboard.setData(ClipboardData(text: place));
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.detail.directions.copied'))),
    );
    analytics.actionSuccess('copyAddress', params: {'activity_id': activityId});
    return;
  }

  final link = choice as MapLink;
  final opened = await _launch(link);
  if (opened) {
    analytics.actionSuccess('openMaps', params: {
      'activity_id': activityId,
      'app': link.app.name,
    });
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.detail.directions.failed'))),
    );
  }
}

/// Which apps to offer. Google Maps and Apple Maps (iOS) always work via their
/// web links; Waze and Android's "other apps" chooser only when installed.
Future<List<MapLink>> _availableApps(String place) async {
  final google = MapLink.forPlace(MapApp.googleMaps, place);
  final apple = MapLink.forPlace(MapApp.appleMaps, place);
  final waze = MapLink.forPlace(MapApp.waze, place);
  final other = MapLink.forPlace(MapApp.otherApps, place);

  if (kIsWeb) return [google, apple, waze];

  final wazeInstalled = await _canLaunch(waze.native!);
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return [apple, google, if (wazeInstalled) waze];
    case TargetPlatform.android:
      return [
        google,
        if (wazeInstalled) waze,
        if (await _canLaunch(other.web)) other,
      ];
    default:
      return [google, apple, waze];
  }
}

Future<bool> _canLaunch(Uri uri) async {
  try {
    return await canLaunchUrl(uri);
  } catch (_) {
    return false;
  }
}

/// Prefers the installed app's own scheme, then the universal web link (which
/// the OS hands to the app when installed, otherwise opens the browser).
Future<bool> _launch(MapLink link) async {
  final native = link.native;
  if (!kIsWeb && native != null && await _canLaunch(native)) {
    if (await _tryLaunch(native)) return true;
  }
  return _tryLaunch(link.web);
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

String _labelKey(MapApp app) => switch (app) {
      MapApp.googleMaps => 'activity.detail.directions.googleMaps',
      MapApp.appleMaps => 'activity.detail.directions.appleMaps',
      MapApp.waze => 'activity.detail.directions.waze',
      MapApp.otherApps => 'activity.detail.directions.otherApps',
    };

IconData _icon(MapApp app) => switch (app) {
      MapApp.googleMaps => Icons.map_rounded,
      MapApp.appleMaps => Icons.map_outlined,
      MapApp.waze => Icons.navigation_rounded,
      MapApp.otherApps => Icons.apps_rounded,
    };
