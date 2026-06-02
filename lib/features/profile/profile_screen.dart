import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_style.dart';
import '../../domain/models/activity_category.dart';
import 'widgets/avatar_drop_zone.dart';

/// The user's profile: an editable identity (avatar / name / handle / bio), a
/// compact (non-clickable) stat strip, selectable interest chips, and a settings
/// list. All state is in-memory for now (no backend) — discovering activities,
/// friends and joined activities live in their own bottom-nav tabs.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Local, in-memory profile state.
  String _name = 'Rares';
  final String _handle = 'rares';
  String _bio = '';
  String? _avatarUrl;
  final Set<ActivityCategory> _interests = {
    ActivityCategory.coffee,
    ActivityCategory.tennis,
  };

  // Mock stats (would come from repositories once wired).
  static const _joined = 3;
  static const _hosted = 1;
  static const _friends = 0;

  AnalyticsService get _analytics => context.read<AnalyticsService>();

  void _comingSoon(String key) {
    _analytics.buttonClicked('settings_$key');
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.tr('profile.comingSoon'))),
    );
  }

  Future<void> _editProfile() async {
    _analytics.buttonClicked('edit_profile');
    final result = await showModalBottomSheet<_ProfileEdits>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        name: _name,
        bio: _bio,
        analytics: _analytics,
      ),
    );
    if (result == null) return;
    setState(() {
      _name = result.name;
      _bio = result.bio;
    });
    _analytics.actionSuccess('updateProfile');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ---- Header ----
          Center(
            child: AvatarDropZone(
              initial: _name.isNotEmpty ? _name[0].toUpperCase() : '?',
              dataUrl: _avatarUrl,
              onChanged: (url) {
                _analytics.buttonClicked('profile_avatar_upload');
                setState(() => _avatarUrl = url);
              },
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(_name,
                style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          ),
          Center(
            child: Text(
              l.tr('profile.handle', {'handle': _handle}),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _bio.isEmpty ? l.tr('profile.bioPlaceholder') : _bio,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _bio.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l.tr('profile.editProfile')),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ---- Compact stat strip (non-clickable) ----
          _SoftCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  _Stat(value: _joined, label: l.tr('profile.stats.joined')),
                  const _StatDivider(),
                  _Stat(value: _hosted, label: l.tr('profile.stats.hosted')),
                  const _StatDivider(),
                  _Stat(value: _friends, label: l.tr('profile.stats.friends')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ---- Interests ----
          Text(l.tr('profile.interests'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ActivityCategory.values)
                _InterestChip(
                  category: c,
                  selected: _interests.contains(c),
                  label: l.tr('feed.filters.${c.id}'),
                  onTap: () {
                    _analytics.buttonClicked('interest_${c.id}');
                    setState(() {
                      _interests.contains(c)
                          ? _interests.remove(c)
                          : _interests.add(c);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 28),

          // ---- Settings ----
          Text(l.tr('profile.settings.title'),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _SoftCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  label: l.tr('profile.settings.notifications'),
                  onTap: () => _comingSoon('notifications'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  label: l.tr('profile.settings.language'),
                  onTap: () => _comingSoon('language'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: l.tr('profile.settings.privacy'),
                  onTap: () => _comingSoon('privacy'),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: l.tr('profile.settings.logout'),
                  danger: true,
                  onTap: () => _comingSoon('logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A white rounded surface with the app's soft shadow.
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.softShadow(opacity: 0.07, blur: 18),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.black12);
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.category,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final ActivityCategory category;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(category);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? color : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF44403C),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? scheme.error : scheme.primary),
      title: Text(label, style: TextStyle(color: color)),
      trailing: danger
          ? null
          : Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
    );
  }
}

/// Result of the edit sheet.
class _ProfileEdits {
  const _ProfileEdits(this.name, this.bio);
  final String name;
  final String bio;
}

/// Bottom sheet to edit name + bio.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.name,
    required this.bio,
    required this.analytics,
  });

  final String name;
  final String bio;
  final AnalyticsService analytics;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _bio = TextEditingController(text: widget.bio);

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFBF7F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(l.tr('profile.editProfile'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              onChanged: (_) => widget.analytics.inputTyping('profile_name'),
              decoration: const InputDecoration(),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              onChanged: (_) => widget.analytics.inputTyping('profile_bio'),
              decoration:
                  InputDecoration(hintText: l.tr('profile.bioPlaceholder')),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _ProfileEdits(_name.text.trim(), _bio.text.trim()),
              ),
              child: Text(l.tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}
