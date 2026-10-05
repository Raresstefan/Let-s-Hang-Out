import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/legal/legal.dart';
import '../../core/moderation/content_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../data/account/account_deletion_service.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/interests/interest_catalog.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/host_stats.dart';
import '../legal/legal_doc_screen.dart';
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
  // Local, in-memory profile state (seeded from the signed-in account).
  String _name = 'Rares';
  String _handle = 'rares';
  String _bio = '';
  String? _avatarUrl;
  // Interest ids the user picked (catalog ids or custom free-text). Hydrated
  // from the stored profile; empty until loaded.
  final Set<String> _interests = {};

  // Live stats, derived from the activities the user is enrolled in. Hosted =
  // activities they own; Joined = activities they're a member of but don't host.
  // Friends has no backend yet, so it stays 0.
  int _joined = 0;
  int _hosted = 0;
  int _friends = 0;
  HostStats _hostStats = const HostStats();

  // True while deleteAccount() is in flight. Blocks the screen with a spinner
  // so the (possibly slow) redirect to the sign-in screen never looks like a
  // frozen/no-op tap — the auth gate swap can lag a beat behind the network
  // call completing.
  bool _deletingAccount = false;

  AnalyticsService get _analytics => context.read<AnalyticsService>();

  @override
  void initState() {
    super.initState();
    // Seed identity from the signed-in user (Google name/avatar).
    final auth = context.read<AuthService>();
    final name = auth.displayName;
    if (name != null && name.isNotEmpty) {
      _name = name;
      _handle = name.split(' ').first.toLowerCase();
    }
    _avatarUrl = auth.photoUrl;
    _loadStats();
    _loadProfile();
  }

  /// Hydrates the editable profile (bio + interests) from the stored `users`
  /// doc so they survive restarts. Identity (name/avatar) is already seeded from
  /// the auth session above; a stored displayName takes precedence if present.
  Future<void> _loadProfile() async {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    try {
      final profile = await context.read<UserRepository>().fetchProfile(uid);
      if (!mounted || profile == null) return;
      setState(() {
        _bio = profile.bio;
        if (profile.displayName.trim().isNotEmpty) {
          _name = profile.displayName;
          _handle = profile.displayName.split(' ').first.toLowerCase();
        }
        _interests
          ..clear()
          ..addAll(profile.interests);
        _friends = profile.friendIds.length;
      });
    } catch (_) {
      // Offline / transient read — keep the auth-seeded defaults.
    }
  }

  /// Persists the full editable profile (identity + bio + interests) to the
  /// `users` doc. Best-effort: optimistic UI already updated; swallow errors.
  Future<void> _persistProfile() async {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    try {
      await context.read<UserRepository>().upsertProfile(
        AppUser(
          id: uid,
          displayName: _name,
          avatarUrl: _avatarUrl,
          bio: _bio,
          interests: _interests.toList(),
        ),
      );
    } catch (_) {
      // Ignore — a later save / sign-in re-syncs.
    }
  }

  /// Opens the Tinder-style interest picker, then persists the new selection.
  Future<void> _editInterests() async {
    _analytics.buttonClicked('edit_interests');
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _InterestsSheet(initial: _interests, analytics: _analytics),
    );
    if (result == null) return;
    setState(() {
      _interests
        ..clear()
        ..addAll(result);
    });
    _persistProfile();
    _analytics.actionSuccess('updateInterests');
  }

  /// Pulls the user's activities once and tallies hosted vs joined. Failures are
  /// swallowed (the stat strip just shows the last known / zero counts) — this
  /// is a glanceable summary, not a critical path.
  Future<void> _loadStats() async {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    try {
      final mine = await context.read<ActivityRepository>().fetchMyActivities(
        uid,
      );
      if (!mounted) return;
      var hosted = 0;
      var joined = 0;
      for (final Activity a in mine) {
        if (a.hostId == uid) {
          hosted++;
        } else {
          joined++;
        }
      }
      final stats = await context.read<ActivityRepository>().hostStats(uid);
      if (!mounted) return;
      setState(() {
        _hosted = hosted;
        _joined = joined;
        _hostStats = stats;
      });
    } catch (_) {
      // Leave counts as-is; offline / transient read errors shouldn't block the
      // profile from rendering.
    }
  }

  Future<void> _logout() async {
    _analytics.buttonClicked('settings_logout');
    // Signing out flips AuthService.isSignedIn → the auth gate shows sign-in.
    await context.read<AuthService>().signOut();
  }

  /// Confirms, then permanently deletes the account via
  /// [AccountDeletionService], which cleans up everything the user
  /// hosted/created/joined (activities, circles, chats, friendships) before
  /// deleting the Firebase auth identity itself.
  Future<void> _deleteAccount() async {
    _analytics.buttonClicked('settings_delete_account');
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('profile.settings.deleteAccountConfirmTitle')),
        content: Text(l.tr('profile.settings.deleteAccountConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.tr('profile.settings.deleteAccountConfirmAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    final auth = context.read<AuthService>();
    final deletion = context.read<AccountDeletionService>();
    final uid = auth.currentUserId;
    try {
      if (uid != null) {
        await deletion.deleteAccountAndData(uid);
      } else {
        await auth.deleteAccount();
      }
      _analytics.actionSuccess('deleteAccount');
      // Deliberately leave _deletingAccount true and don't call setState here:
      // the auth gate in app.dart is about to pop this screen off the stack
      // (it was reached via Navigator.push) and swap to SignInScreen, so the
      // spinner stays up until that happens instead of flashing back to the
      // profile UI.
    } on AccountDeletionRequiresRecentLogin {
      // Session too old for this sensitive op. Sign out so the next sign-in
      // is fresh — the user can then retry immediately and it'll succeed
      // without any re-auth prompt mid-flow.
      await auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.tr('profile.settings.deleteAccountReauthRequired')),
        ),
      );
      // Signed out too (just via a different path) — same reasoning as above.
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('profile.settings.deleteAccountError'))),
      );
    }
  }

  void _comingSoon(String key) {
    _analytics.buttonClicked('settings_$key');
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.tr('profile.comingSoon'))));
  }

  void _openLegal(String key, String asset) {
    _analytics.buttonClicked('settings_$key');
    LegalDocScreen.open(context, AppLocalizations.of(context).tr('legal.$key'),
        asset);
  }

  Future<void> _contact() async {
    _analytics.buttonClicked('settings_contact');
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('legal.contactTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.tr('legal.contactBody')),
            const SizedBox(height: 12),
            Text(
              kContactEmail,
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.tr('common.done')),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l.tr('legal.copyEmail')),
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: kContactEmail));
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                  SnackBar(content: Text(l.tr('legal.emailCopied'))));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    _analytics.buttonClicked('edit_profile');
    final result = await showModalBottomSheet<_ProfileEdits>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditProfileSheet(name: _name, bio: _bio, analytics: _analytics),
    );
    if (result == null) return;
    setState(() {
      _name = result.name;
      _bio = result.bio;
    });
    _persistProfile();
    _analytics.actionSuccess('updateProfile');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('profile.title'))),
      body: Stack(
        children: [
          ListView(
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
                child: Text(
                  _name,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: Text(
                  l.tr('profile.handle', {'handle': _handle}),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_hostStats.hasRating) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.seed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppTheme.seed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.tr('userProfile.hostRating', {
                            'rating': _hostStats.averageRating.toStringAsFixed(
                              1,
                            ),
                            'count': _hostStats.hostedCount,
                          }),
                          style: const TextStyle(
                            color: AppTheme.seed,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
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
                      _Stat(
                        value: _joined,
                        label: l.tr('profile.stats.joined'),
                      ),
                      const _StatDivider(),
                      _Stat(
                        value: _hosted,
                        label: l.tr('profile.stats.hosted'),
                      ),
                      const _StatDivider(),
                      _Stat(
                        value: _friends,
                        label: l.tr('profile.stats.friends'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Interests ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.tr('profile.interests'),
                    style: theme.textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _editInterests,
                    icon: Icon(
                      _interests.isEmpty
                          ? Icons.add_rounded
                          : Icons.edit_outlined,
                      size: 18,
                    ),
                    label: Text(
                      l.tr(
                        _interests.isEmpty
                            ? 'profile.interestsAdd'
                            : 'profile.interestsEdit',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_interests.isEmpty)
                _InterestsEmptyPrompt(
                  text: l.tr('profile.interestsEmpty'),
                  onTap: _editInterests,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in _interests)
                      _InterestChip(
                        interest: InterestCatalog.resolve(id),
                        selected: true,
                        onTap: _editInterests,
                      ),
                  ],
                ),
              const SizedBox(height: 28),

              // ---- Settings ----
              Text(
                l.tr('profile.settings.title'),
                style: theme.textTheme.titleMedium,
              ),
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
                      label: l.tr('legal.privacy'),
                      onTap: () => _openLegal('privacy', kPrivacyAsset),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      label: l.tr('legal.terms'),
                      onTap: () => _openLegal('terms', kTermsAsset),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      label: l.tr('legal.contactTitle'),
                      onTap: _contact,
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      label: l.tr('profile.settings.logout'),
                      danger: true,
                      onTap: _logout,
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      label: l.tr('profile.settings.deleteAccount'),
                      danger: true,
                      onTap: _deletingAccount ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_deletingAccount)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
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
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.seed;
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
            Text(interest.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              interest.label,
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

/// Inviting empty state for the interests section — a dashed-feel prompt card
/// that opens the picker.
class _InterestsEmptyPrompt extends StatelessWidget {
  const _InterestsEmptyPrompt({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.seed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.seed.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinder-style interest picker: grouped selectable chips + an "Other" chip that
/// lets the user add their own. Returns the new selection set on Save.
class _InterestsSheet extends StatefulWidget {
  const _InterestsSheet({required this.initial, required this.analytics});

  final Set<String> initial;
  final AnalyticsService analytics;

  @override
  State<_InterestsSheet> createState() => _InterestsSheetState();
}

class _InterestsSheetState extends State<_InterestsSheet> {
  late final Set<String> _selected = {...widget.initial};

  /// Custom (non-catalog) interests the user has selected — rendered as their
  /// own removable group so they don't get lost.
  List<String> get _customSelected =>
      _selected.where((id) => !InterestCatalog.byId.containsKey(id)).toList();

  void _toggle(String id) {
    widget.analytics.buttonClicked('interest_$id');
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  Future<void> _addCustom() async {
    widget.analytics.buttonClicked('interest_add_custom');
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('profile.interestsOtherTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l.tr('profile.interestsOtherHint'),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l.tr('profile.interestsAdd')),
          ),
        ],
      ),
    );
    final cleaned = text?.trim() ?? '';
    if (cleaned.isEmpty) return;
    if (ContentFilter.hasBlocked(cleaned)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tr('moderation.blocked'))));
      return;
    }
    // Store custom interests as a normalized id so duplicates collapse.
    final id = cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    setState(() => _selected.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final custom = _customSelected;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFBF7F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.tr('profile.interestsTitle'),
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          l.tr('profile.interestsSubtitle', {
                            'count': _selected.length,
                          }),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final group in InterestCatalog.groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      child: Text(
                        group.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in group.interests)
                          _InterestChip(
                            interest: i,
                            selected: _selected.contains(i.id),
                            onTap: () => _toggle(i.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Your own / custom interests + the add button.
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 10),
                    child: Text(
                      l.tr('profile.interestsYourOwn'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in custom)
                        _InterestChip(
                          interest: InterestCatalog.resolve(id),
                          selected: true,
                          onTap: () => _toggle(id),
                        ),
                      _AddInterestChip(
                        label: l.tr('profile.interestsOther'),
                        onTap: _addCustom,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(l.tr('common.save')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "+ Other" chip that opens the add-your-own dialog.
class _AddInterestChip extends StatelessWidget {
  const _AddInterestChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.seed.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: AppTheme.seed),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.seed,
                fontWeight: FontWeight.w700,
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
  final VoidCallback? onTap;
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
  String? _error;

  void _save() {
    final name = _name.text.trim();
    final bio = _bio.text.trim();
    if (ContentFilter.hasBlocked(name) || ContentFilter.hasBlocked(bio)) {
      setState(
          () => _error = AppLocalizations.of(context).tr('moderation.blocked'));
      return;
    }
    Navigator.of(context).pop(_ProfileEdits(name, bio));
  }

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
            Text(
              l.tr('profile.editProfile'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
              decoration: InputDecoration(
                hintText: l.tr('profile.bioPlaceholder'),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(l.tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}
