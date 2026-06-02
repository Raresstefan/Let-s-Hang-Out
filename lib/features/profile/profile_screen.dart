import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

/// User profile. Stubbed with static stats for the first version.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(
            child: CircleAvatar(radius: 44, child: Text('R', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Rares', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          _stat(context, l.tr('profile.activitiesJoined'), '3'),
          _stat(context, l.tr('profile.activitiesHosted'), '1'),
          _stat(context, l.tr('profile.friendsCount'), '0'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
}
