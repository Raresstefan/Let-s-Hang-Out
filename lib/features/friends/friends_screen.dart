import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/friend_request.dart';
import '../profile/profile_avatar_button.dart';
import '../user_profile/user_profile_screen.dart';
import 'friends_controller.dart';

/// Friends home: search to find people, respond to incoming requests, see your
/// pending (outgoing) requests, and your friends list.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Refresh on open so newly-accepted friends / sent requests show up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FriendsController>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    context.read<AnalyticsService>().inputTyping('search_friends');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) context.read<FriendsController>().search(value);
    });
  }

  void _openProfile(AppUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(userId: user.id, initialProfile: user),
      ),
    );
  }

  Future<void> _confirmUnfriend(AppUser user) async {
    final l = AppLocalizations.of(context);
    final name = user.displayName.trim().isNotEmpty
        ? user.displayName
        : l.tr('userProfile.unknown');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('friends.unfriendConfirmTitle')),
        content: Text(l.tr('friends.unfriendConfirmBody', {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.tr('friends.unfriend')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<FriendsController>().unfriend(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.watch<FriendsController>();
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('friends.title')),
        actions: const [ProfileAvatarButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<FriendsController>().load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ---- Search ----
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.tr('friends.searchHint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          context.read<FriendsController>().clearSearch();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Search results (replace the rest while searching) ----
            if (hasQuery) ...[
              _SectionHeader(l.tr('friends.resultsTitle')),
              if (c.searching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (c.searchResults.isEmpty)
                _EmptyHint(l.tr('friends.noResults'))
              else
                for (final u in c.searchResults)
                  _UserTile(
                    key: ValueKey('search_${u.id}'),
                    user: u,
                    onTap: () => _openProfile(u),
                    trailing: _AddFriendToggle(
                      key: ValueKey('toggle_${u.id}'),
                      userId: u.id,
                    ),
                  ),
            ] else ...[
              // ---- Incoming requests ----
              if (c.incoming.isNotEmpty) ...[
                _SectionHeader(l.tr('friends.requestsTitle')),
                for (final e in c.incoming)
                  _UserTile(
                    user: e.user,
                    onTap: () => _openProfile(e.user),
                    subtitle: l.tr('friends.wantsToBeFriends'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AddButton(
                          label: l.tr('friends.accept'),
                          onPressed: () =>
                              context.read<FriendsController>().accept(e),
                        ),
                        const SizedBox(width: 6),
                        _GhostButton(
                          label: l.tr('friends.deny'),
                          onPressed: () =>
                              context.read<FriendsController>().decline(e),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // ---- Outgoing / pending ----
              if (c.outgoing.isNotEmpty) ...[
                _SectionHeader(l.tr('friends.pendingTitle')),
                for (final e in c.outgoing)
                  _UserTile(
                    user: e.user,
                    onTap: () => _openProfile(e.user),
                    subtitle: l.tr('friends.requested'),
                    trailing: _GhostButton(
                      label: l.tr('friends.cancel'),
                      onPressed: () =>
                          context.read<FriendsController>().cancel(e),
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // ---- Friends list ----
              _SectionHeader(l.tr('friends.friendsTitle')),
              if (c.loading && c.friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (c.friends.isEmpty)
                _EmptyHint(l.tr('friends.empty'))
              else
                for (final u in c.friends)
                  _UserTile(
                    key: ValueKey('friend_${u.id}'),
                    user: u,
                    onTap: () => _openProfile(u),
                    trailing: IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: l.tr('friends.unfriend'),
                      onPressed: () => _confirmUnfriend(u),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A person row: avatar + name (+ optional subtitle) + optional trailing action.
class _UserTile extends StatelessWidget {
  const _UserTile({
    super.key,
    required this.user,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final AppUser user;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

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
        width: 46,
        height: 46,
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
                _initial(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
    );
  }

  String _initial(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return (cleaned.isEmpty ? '?' : cleaned[0]).toUpperCase();
  }
}

/// Instagram-style add/cancel toggle for a search result. Filled "Add friend"
/// when not requested; tapping sends and flips to a subtle "Requested" look;
/// tapping again cancels and flips back. Disabled (Friends) when already linked.
class _AddFriendToggle extends StatefulWidget {
  const _AddFriendToggle({super.key, required this.userId});
  final String userId;

  @override
  State<_AddFriendToggle> createState() => _AddFriendToggleState();
}

class _AddFriendToggleState extends State<_AddFriendToggle> {
  FriendshipStatus _status = FriendshipStatus.none;
  bool _loaded = false; // false only until the first status read resolves
  bool _busy = false; // a network action is in flight

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await context.read<FriendsController>().statusWith(
        widget.userId,
      );
      if (mounted) setState(() => _status = s);
    } catch (_) {
      // Keep whatever we have; never get stuck on a failed read.
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final c = context.read<FriendsController>();
    final previous = _status;
    // Optimistic flip (instant, Instagram-style); revert on failure.
    final optimistic = previous == FriendshipStatus.requestedByMe
        ? FriendshipStatus.none
        : previous == FriendshipStatus.none
        ? FriendshipStatus.requestedByMe
        : previous; // friends/incoming handled by the action, not a toggle
    setState(() {
      _busy = true;
      _status = optimistic;
    });
    try {
      switch (previous) {
        case FriendshipStatus.requestedByMe:
          await c.cancelRequestTo(widget.userId);
          break;
        case FriendshipStatus.none:
          await c.sendRequest(widget.userId);
          break;
        case FriendshipStatus.incoming:
          for (final e in c.incoming) {
            if (e.request.fromId == widget.userId) {
              await c.accept(e);
              break;
            }
          }
          break;
        case FriendshipStatus.friends:
          break; // no-op
      }
    } catch (_) {
      if (mounted) setState(() => _status = previous); // revert
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_loaded) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    switch (_status) {
      case FriendshipStatus.friends:
        return _GhostButton(
          label: l.tr('friends.alreadyFriends'),
          onPressed: null,
        );
      case FriendshipStatus.requestedByMe:
        // Subtle "Requested" state — tap to cancel (toggles back).
        return _GhostButton(
          label: l.tr('friends.requested'),
          onPressed: _busy ? null : _toggle,
        );
      case FriendshipStatus.incoming:
        return _AddButton(
          label: l.tr('friends.accept'),
          onPressed: _busy ? null : _toggle,
        );
      case FriendshipStatus.none:
        return _AddButton(
          label: l.tr('friends.add'),
          onPressed: _busy ? null : _toggle,
        );
    }
  }
}

/// Filled primary action (Add / Accept). A null [onPressed] disables it.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label),
  );
}

/// Subtle outlined action (Deny / Cancel / Requested). A null [onPressed]
/// disables it.
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label),
  );
}
