import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

/// Friends list (Facebook-style). Stubbed for the first version — wired to the
/// social graph once the backend lands.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('friends.title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.tr('friends.empty'), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
