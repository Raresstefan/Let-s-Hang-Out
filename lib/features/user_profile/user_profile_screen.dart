import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/interests/interest_catalog.dart';
import '../../domain/models/app_user.dart';

/// Read-only view of *another* user's profile — opened by tapping their avatar
/// in an activity's who's-going row. Deliberately separate from the editable
/// [ProfileScreen]: no edit controls, no settings, just identity + bio +
/// interests so people can get a feel for who they're hanging out with.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialProfile,
    this.isHost = false,
  });

  final String userId;

  /// Optional already-loaded profile (from the who's-going row) so the screen
  /// renders instantly; a fresh copy is still fetched to fill bio/interests.
  final AppUser? initialProfile;

  /// Shows a "Host" badge when this user hosts the activity we came from.
  final bool isHost;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  AppUser? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    context
        .read<AnalyticsService>()
        .activityOnLoad('user_profile_${widget.userId}');
    _load();
  }

  Future<void> _load() async {
    try {
      final fetched =
          await context.read<UserRepository>().fetchProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        if (fetched != null) _profile = fetched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = _profile;

    final name = (p != null && p.displayName.trim().isNotEmpty)
        ? p.displayName
        : l.tr('userProfile.unknown');
    final handle = name.split(' ').first.toLowerCase();
    final hasPhoto = p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('userProfile.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 8),
          // ---- Avatar ----
          Center(
            child: Container(
              width: 116,
              height: 116,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasPhoto ? null : AppTheme.brandGradient,
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(p.avatarUrl!), fit: BoxFit.cover)
                    : null,
                boxShadow: AppTheme.softShadow(opacity: 0.14, blur: 18),
              ),
              child: hasPhoto
                  ? null
                  : Text(
                      _initial(name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 44),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(name,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
          ),
          Center(
            child: Text(
              l.tr('profile.handle', {'handle': handle}),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text(l.tr('activity.detail.host'),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),

          // ---- Bio ----
          if (p != null && p.bio.trim().isNotEmpty) ...[
            Text(l.tr('userProfile.about'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(p.bio,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 24),
          ],

          // ---- Interests ----
          if (p != null && p.interests.isNotEmpty) ...[
            Text(l.tr('profile.interests'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in p.interests)
                  _ReadOnlyInterestChip(
                      interest: InterestCatalog.resolve(id)),
              ],
            ),
          ],

          // ---- Empty / loading states ----
          if (_loading && p == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_loading &&
              (p == null ||
                  (p.bio.trim().isEmpty && p.interests.isEmpty)))
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  l.tr('userProfile.empty'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initial(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return (cleaned.isEmpty ? '?' : cleaned[0]).toUpperCase();
  }
}

/// A non-interactive interest chip for the read-only profile.
class _ReadOnlyInterestChip extends StatelessWidget {
  const _ReadOnlyInterestChip({required this.interest});

  final Interest interest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: AppTheme.softShadow(opacity: 0.05, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(interest.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            interest.label,
            style: const TextStyle(
              color: Color(0xFF44403C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
