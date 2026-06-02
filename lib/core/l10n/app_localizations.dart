import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// JSON-backed localization. Loads `assets/i18n/<locale>.json` and resolves
/// dot-notation keys, e.g. `tr('activity.placeholder.title')`.
///
/// Supports `{name}` interpolation via the optional [args] map:
///   tr('activity.enrolledCount', {'count': 5})  ->  "5 enrolled"
class AppLocalizations {
  AppLocalizations(this._strings);

  final Map<String, dynamic> _strings;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l != null, 'AppLocalizations not found in context');
    return l!;
  }

  static Future<AppLocalizations> load(Locale locale) async {
    final name = locale.countryCode != null && locale.countryCode!.isNotEmpty
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    final jsonString = await rootBundle.loadString('assets/i18n/$name.json');
    final map = json.decode(jsonString) as Map<String, dynamic>;
    return AppLocalizations(map);
  }

  /// Resolve a dot-notation key. Returns the key itself if missing (so missing
  /// strings are visible during development rather than crashing).
  String tr(String key, [Map<String, Object?>? args]) {
    dynamic node = _strings;
    for (final part in key.split('.')) {
      if (node is Map<String, dynamic> && node.containsKey(part)) {
        node = node[part];
      } else {
        return key;
      }
    }
    if (node is! String) return key;

    var result = node;
    if (args != null) {
      args.forEach((k, v) {
        result = result.replaceAll('{$k}', '${v ?? ''}');
      });
    }
    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  // Only en is shipped for now.
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
