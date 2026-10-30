import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';
import '../create/create_activity_screen.dart';
import '../friends/friends_controller.dart';

/// The post-hang recap for one past activity: rate it, add the people you met,
/// and "Hang again" (pre-fill a new activity with the same crew).
class RecapSheet extends StatefulWidget {
  const RecapSheet({super.key, required this.activity});

  final Activity activity;

  /// Opens the recap as a modal bottom sheet. Resolves to `true` if the user
  /// rated the activity (so the caller can drop the recap prompt immediately).
  static Future<bool> show(BuildContext context, Activity activity) async {
    final rated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecapSheet(activity: activity),
    );
    return rated ?? false;
  }

  @override
  State<RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<RecapSheet> {
  int _rating = 0;
  bool _rated = false;
  List<AppUser> _others = [];

  /// The in-flight rating write, if any — "Done" awaits it so the caller's
  /// refresh sees the persisted rating (avoids a race where the list refetches
  /// before the write commits and the recap card lingers).
  Future<void>? _pendingRate;

  @override
  void initState() {
    super.initState();
    context.read<AnalyticsService>().activityOnLoad(
      'recap_${widget.activity.id}',
    );
    final uid = context.read<AuthService>().currentUserId;
    _rating = uid == null ? 0 : (widget.activity.ratings[uid] ?? 0);
    _rated = _rating > 0;
    _loadOthers(uid);
  }

  Future<void> _loadOthers(String? uid) async {
    final otherIds = widget.activity.memberIds
        .where((id) => id != uid)
        .toList();
    if (otherIds.isEmpty) return;
    try {
      final profiles = await context.read<UserRepository>().fetchProfiles(
        otherIds,
      );
      if (mounted) setState(() => _others = profiles);
    } catch (_) {
      /* leave empty */
    }
  }

  Future<void> _rate(int stars) async {
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    final analytics = context.read<AnalyticsService>();
    final repo = context.read<ActivityRepository>();
    setState(() {
      _rating = stars;
      _rated = true;
    });
    analytics.buttonClicked(
      'rate_activity',
      params: {'activity_id': widget.activity.id, 'rating': stars},
    );
    _pendingRate = () async {
      try {
        await repo.rateActivity(widget.activity.id, uid, stars);
        analytics.actionSuccess(
          'rateActivity',
          params: {'activity_id': widget.activity.id},
        );
      } catch (_) {
        /* optimistic; ignore */
      }
    }();
    await _pendingRate;
  }

  /// Closes the sheet, first awaiting any in-flight rating write so the caller's
  /// refresh reflects it. Returns whether a rating was made.
  Future<void> _done() async {
    await _pendingRate;
    if (mounted) Navigator.of(context).pop(_rated);
  }

  Future<void> _hangAgain() async {
    final a = widget.activity;
    context.read<AnalyticsService>().buttonClicked(
      'hang_again',
      params: {'activity_id': a.id},
    );
    await _pendingRate;
    if (!mounted) return;
    Navigator.of(context).pop(_rated); // close the sheet first
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateActivityScreen(
          prefillTitle: a.title,
          prefillPlace: a.placeSuggestion,
          prefillCity: a.city,
          prefillCategory: a.category,
          prefillMemberIds: a.memberIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
              l.tr('postHang.recapPrompt', {'title': widget.activity.title}),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // ---- Rating (auto-saves on tap) ----
            Text(l.tr('postHang.rateLabel'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => _rate(i),
                    iconSize: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppTheme.seed,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Confirmation sits on its own line (no overflow) once rated.
            Center(
              child: Text(
                _rated ? l.tr('postHang.thanks') : l.tr('postHang.tapToRate'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- People you met ----
            if (_others.isNotEmpty) ...[
              Text(
                l.tr('postHang.peopleYouMet'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final u in _others) _MetPersonTile(user: u),
              const SizedBox(height: 12),
            ],

            // ---- Actions: Done (rating already saved) + optional Hang again ----
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _hangAgain,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.tr('postHang.hangAgain')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _done,
                child: Text(l.tr('common.done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A person you met, with a status-aware Add-friend button (reuses the friends
/// flow). Mirrors the search-result toggle.
class _MetPersonTile extends StatefulWidget {
  const _MetPersonTile({required this.user});
  final AppUser user;

  @override
  State<_MetPersonTile> createState() => _MetPersonTileState();
}

class _MetPersonTileState extends State<_MetPersonTile> {
  FriendshipStatus _status = FriendshipStatus.none;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<FriendsController>().statusWith(
        widget.user.id,
      );
      if (mounted) setState(() => _status = s);
    } catch (_) {
      /* ignore */
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = FriendshipStatus.requestedByMe; // optimistic
    });
    context.read<AnalyticsService>().buttonClicked(
      'add_friend_from_recap',
      params: {'target_user_id': widget.user.id},
    );
    try {
      await context.read<FriendsController>().sendRequest(widget.user.id);
    } catch (_) {
      if (mounted) setState(() => _status = FriendshipStatus.none);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = widget.user.displayName.trim().isNotEmpty
        ? widget.user.displayName
        : l.tr('userProfile.unknown');
    final hasPhoto =
        widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty;

    Widget trailing;
    if (!_loaded) {
      trailing = const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      switch (_status) {
        case FriendshipStatus.friends:
          trailing = Text(
            l.tr('friends.alreadyFriends'),
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          );
          break;
        case FriendshipStatus.requestedByMe:
          trailing = Text(
            l.tr('friends.requested'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
          break;
        default:
          trailing = FilledButton(
            onPressed: _busy ? null : _add,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.tr('friends.add')),
          );
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasPhoto ? null : AppTheme.brandGradient,
          image: hasPhoto
              ? DecorationImage(
                  image: CoverImage.providerFor(widget.user.avatarUrl!),
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
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}
