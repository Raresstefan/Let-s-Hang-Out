import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
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

  // Bumped each time the My Activities tab is opened so it remounts and
  // re-queries Firestore (its data is loaded once per mount). Without this the
  // IndexedStack keeps the page alive and it never reflects a fresh join.
  int _myActivitiesEpoch = 0;

  // Order of the four tabs in the bottom bar (Discover lives behind Profile's
  // left side; we keep Feed as index 0 so the app opens on Discover).
  List<Widget> get _pages => [
        const FeedScreen(),
        const FriendsScreen(),
        MyActivitiesScreen(key: ValueKey(_myActivitiesEpoch)),
        const ProfileScreen(),
      ];

  Future<void> _openCreate() async {
    context.read<AnalyticsService>().buttonClicked('create_activity_fab');
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CreateActivityScreen(),
      ),
    );
    if (!mounted || created != true) return;
    // A new activity was created: jump to My Activities and remount it so it
    // re-queries and shows the activity we now host. Bumping the epoch refreshes
    // it even if we were already on that tab.
    setState(() {
      _index = 2;
      _myActivitiesEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      // The create button lives *inside* the bottom menu (see _CreateButton),
      // not as a floating overlay — so it never covers the activity cards.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.softShadow(opacity: 0.12, blur: 22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
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
              _CreateButton(
                label: l.tr('nav.create'),
                onTap: _openCreate,
              ),
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
      ),
    );
  }

  void _select(int i) {
    context.read<AnalyticsService>().buttonClicked('nav_tab_$i');
    setState(() {
      _index = i;
      // Remount My Activities on each visit so it re-fetches (reflects joins).
      if (i == 2) _myActivitiesEpoch++;
    });
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
    final primary = Theme.of(context).colorScheme.primary;
    final color =
        selected ? primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tonal pill behind the icon marks the active tab.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(selected ? selectedIcon : icon,
                    color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre "+" item of the bottom menu. It lives inside the bar (not as a
/// floating overlay) and is the most highlighted action: a filled primary
/// circle that visually pops above the flat nav icons.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.seed.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
