import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/circle.dart';
import '../chat/chat_screen.dart';
import '../create/create_activity_screen.dart';
import '../friends/friends_controller.dart';
import '../user_profile/user_profile_screen.dart';
import 'circles_controller.dart';

/// One circle: members, persistent chat, "Plan a hangout", and invite friends.
class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  Circle? _circle;
  Map<String, AppUser> _members = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<AnalyticsService>().activityOnLoad(
      'circle_${widget.circleId}',
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final circle = await context.read<CircleRepository>().fetchCircle(
        widget.circleId,
      );
      if (!mounted || circle == null) {
        setState(() => _loading = false);
        return;
      }
      final profiles = await context.read<UserRepository>().fetchProfiles(
        circle.memberIds,
      );
      if (!mounted) return;
      setState(() {
        _circle = circle;
        _members = {for (final p in profiles) p.id: p};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChat() {
    final c = _circle!;
    context.read<AnalyticsService>().buttonClicked(
      'open_circle_chat',
      params: {'circle_id': c.id},
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: c.id, title: c.name),
      ),
    );
  }

  Future<void> _planHangout() async {
    final c = _circle!;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    context.read<AnalyticsService>().buttonClicked(
      'plan_circle_hangout',
      params: {'circle_id': c.id},
    );
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CreateActivityScreen(circleId: c.id, prefillMemberIds: c.memberIds),
      ),
    );
    if (created == true) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('circles.hangoutPlanned'))),
      );
    }
  }

  void _openMember(AppUser u) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: u.id, initialProfile: u),
      ),
    );
  }

  Future<void> _invite() async {
    final c = _circle!;
    final l = AppLocalizations.of(context);
    final friends = context.read<FriendsController>().friends;
    // Friends not already in the circle.
    final candidates = friends
        .where((f) => !c.memberIds.contains(f.id))
        .toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvitePickerSheet(
        title: l.tr('circles.selectMembers'),
        candidates: candidates,
        emptyHint: l.tr('circles.noFriendsToAdd'),
      ),
    );
    if (picked == null || !mounted) return;
    await context.read<CirclesController>().invite(c, picked);
    await _load();
  }

  Future<void> _leave() async {
    final c = _circle!;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('circles.leave.title')),
        content: Text(l.tr('circles.leave.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.tr('circles.leave.confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<CirclesController>().leave(c);
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('circles.leave.done'))),
      );
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('circles.leave.failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = _circle;
    final uid = context.read<AuthService>().currentUserId;
    // The creator can't leave their own circle.
    final canLeave = c != null && uid != null && uid != c.creatorId;

    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? l.tr('circles.title')),
        actions: [
          if (canLeave)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'leave') _leave();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout_rounded),
                    title: Text(l.tr('circles.leave.action')),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
          ? Center(child: Text(l.tr('circles.empty')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.seed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          c.emoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(c.name, style: theme.textTheme.headlineSmall),
                      Text(
                        l.tr('circles.memberCount', {'count': c.memberCount}),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _planHangout,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l.tr('circles.planHangout')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(l.tr('circles.openChat')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.tr('circles.members'),
                      style: theme.textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: _invite,
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(l.tr('circles.invite')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final id in c.memberIds)
                  _MemberTile(
                    user: _members[id] ?? AppUser(id: id, displayName: ''),
                    isCreator: id == c.creatorId,
                    onTap: () => _openMember(
                      _members[id] ?? AppUser(id: id, displayName: ''),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.user,
    required this.isCreator,
    required this.onTap,
  });

  final AppUser user;
  final bool isCreator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.trim().isNotEmpty
        ? user.displayName
        : AppLocalizations.of(context).tr('userProfile.unknown');
    final hasPhoto = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasPhoto ? null : AppTheme.brandGradient,
          image: hasPhoto
              ? DecorationImage(
                  image: CoverImage.providerFor(user.avatarUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasPhoto
            ? null
            : Text(
                (name.isEmpty ? '?' : name[0]).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Text(name),
      trailing: isCreator
          ? const Icon(Icons.star_rounded, color: AppTheme.accent, size: 20)
          : null,
    );
  }
}

/// Simple single-pick invite sheet (returns the chosen friend's uid).
class _InvitePickerSheet extends StatelessWidget {
  const _InvitePickerSheet({
    required this.title,
    required this.candidates,
    required this.emptyHint,
  });

  final String title;
  final List<AppUser> candidates;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                emptyHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final u in candidates)
                    ListTile(
                      onTap: () => Navigator.of(context).pop(u.id),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.seed.withValues(alpha: 0.15),
                        backgroundImage:
                            (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                            ? CoverImage.providerFor(u.avatarUrl!)
                            : null,
                        child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                            ? Text(
                                (u.displayName.isEmpty ? '?' : u.displayName[0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.seed,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        u.displayName.trim().isEmpty
                            ? AppLocalizations.of(
                                context,
                              ).tr('userProfile.unknown')
                            : u.displayName,
                      ),
                      trailing: const Icon(Icons.add_rounded),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
