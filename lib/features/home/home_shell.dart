import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../create/create_activity_screen.dart';
import '../feed/feed_screen.dart';
import '../friends/friends_screen.dart';
import '../my_activities/my_activities_screen.dart';
import '../profile/profile_screen.dart';

/// App scaffold with the bottom menu described in the spec:
/// Profile · Friends · [ + ] (centre, most highlighted) · My Activities.
/// The Discover feed is the landing surface (the '+' opens create as a sheet).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Order of the four tabs in the bottom bar (Discover lives behind Profile's
  // left side; we keep Feed as index 0 so the app opens on Discover).
  late final List<Widget> _pages = const [
    FeedScreen(),
    FriendsScreen(),
    MyActivitiesScreen(),
    ProfileScreen(),
  ];

  void _openCreate() {
    context.read<AnalyticsService>().buttonClicked('create_activity_fab');
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateActivityScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openCreate,
        tooltip: l.tr('nav.create'),
        elevation: 6,
        child: const Icon(Icons.add, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore,
              label: l.tr('feed.title'),
              selected: _index == 0,
              onTap: () => _select(0),
            ),
            _NavItem(
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: l.tr('nav.friends'),
              selected: _index == 1,
              onTap: () => _select(1),
            ),
            const SizedBox(width: 48), // notch gap for the FAB
            _NavItem(
              icon: Icons.event_available_outlined,
              selectedIcon: Icons.event_available,
              label: l.tr('nav.myActivities'),
              selected: _index == 2,
              onTap: () => _select(2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: l.tr('nav.profile'),
              selected: _index == 3,
              onTap: () => _select(3),
            ),
          ],
        ),
      ),
    );
  }

  void _select(int i) {
    context.read<AnalyticsService>().buttonClicked('nav_tab_$i');
    setState(() => _index = i);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              Text(label,
                  style: TextStyle(color: color, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
