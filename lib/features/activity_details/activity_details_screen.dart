import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/links/activity_links.dart';
import '../../core/share/share_origin.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_style.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/report.dart';
import '../chat/chat_screen.dart';
import '../safety/safety_actions.dart';
import '../user_profile/user_profile_screen.dart';
import 'map_links.dart';
import '../feed/feed_controller.dart';
import '../create/create_activity_screen.dart';
import '../story_card/story_card_screen.dart';

/// Modern activity details: a stretchy collapsing cover hero (SliverAppBar) with
/// glass back/share controls, the title + category over the photo, then meta,
/// about, who's-going avatars and a get-directions location card on the warm surface, with a
/// gradient Join bar pinned to the bottom. Reads the live activity from
/// [FeedController] so like/join changes reflect instantly.
class ActivityDetailsScreen extends StatefulWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.activityId,
    this.initialActivity,
  });

  final String activityId;

  /// An activity passed in directly (from My Activities / the chat header),
  /// used when it isn't in the live feed list — e.g. a joined, past, or
  /// circle-private activity that Discover doesn't surface.
  final Activity? initialActivity;

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  // Live updates from the backend, so a participant sees the host's edits or
  // cancellation while the screen is open.
  late final StreamSubscription<Activity?> _live =
      context.read<FeedController>().follow(widget.activityId);

  String get activityId => widget.activityId;
  Activity? get initialActivity => widget.initialActivity;

  @override
  void initState() {
    super.initState();
    _live;
  }

  @override
  void dispose() {
    _live.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = context.watch<FeedController>();
    final uid = context.watch<AuthService>().currentUserId;

    // Surface a transient action error (e.g. an offline like/join) once.
    final actionError = controller.consumeActionError();
    if (actionError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tr('common.error.$actionError'))),
        );
      });
    }

    // Prefer the live feed copy (keeps like/join reactive); fall back to the
    // activity passed in (joined / past / circle-private ones aren't in the
    // feed list).
    final activity = controller.lookup(activityId) ?? initialActivity;

    if (activity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.tr('feed.empty'))),
      );
    }

    final a = activity;
    final catColor = CategoryStyle.color(a.category);
    final joined = uid != null && a.isMember(uid);
    final removed = uid != null && a.isRemoved(uid);
    final liked = uid != null && a.isLikedBy(uid);
    final hasChat = a.memberIds.length >= 2;
    final started = !a.startAt.isAfter(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HeroAppBar(activity: a, liked: liked, catColor: catColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              // The whole body owns one member-profile fetch (via
              // _EnrolledSection) so the meta card's "X enrolled" and the
              // who's-going "N going" both exclude deleted accounts from the
              // same source, without fetching twice.
              child: _EnrolledSection(
                activity: a,
                currentUid: uid,
                catColor: catColor,
                hasChat: hasChat,
                joined: joined,
                l: l,
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _JoinBar(
        joined: joined,
        blockedLabel: a.cancelled
            ? l.tr('activity.cancel.banner')
            : removed
            ? l.tr('safety.removedFromActivity')
            : (!joined && started)
            ? l.tr('activity.detail.started')
            : null,
        joinLabel: l.tr('common.join'),
        joinedLabel: l.tr('common.joined'),
        leaveLabel: l.tr('activity.detail.leave.action'),
        onJoin: () => _joinAndSuggestStory(context, a, l),
        // Hosts can't leave their own hangout; past ones are history.
        onLeave: joined && uid != a.hostId && !started
            ? () => _confirmLeave(context, a, l)
            : null,
      ),
    );
  }
}

/// Joins, then (on success, public activities only) nudges the user to share
/// a story card so their friends see it.
Future<void> _joinAndSuggestStory(
  BuildContext context,
  Activity a,
  AppLocalizations l,
) async {
  final feed = context.read<FeedController>();
  final uid = context.read<AuthService>().currentUserId;
  final messenger = ScaffoldMessenger.of(context);
  await feed.join(a);
  if (!context.mounted || uid == null || !canShareStory(a)) return;
  final updated = feed.lookup(a.id);
  if (updated == null || !updated.isMember(uid)) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l.tr('storyCard.joinedHint')),
      duration: const Duration(seconds: 6),
      // A snack bar with an action stays up by default — over the chat
      // composer and tab bar. Only screen-reader users keep it until they act.
      persist: MediaQuery.accessibleNavigationOf(context),
      action: SnackBarAction(
        label: l.tr('storyCard.joinedAction'),
        onPressed: () {
          if (context.mounted) StoryCardScreen.open(context, updated);
        },
      ),
    ),
  );
}

/// Opens the native OS share sheet (Messenger, WhatsApp, Gmail, …) with a short
/// invite message describing the activity. [origin] is the tapped button (see
/// [shareOriginOf]).
Future<void> _shareActivity(
  BuildContext context,
  Activity a,
  AppLocalizations l,
  Rect origin,
) async {
  // Capture before the await so we don't touch context across the async gap.
  final analytics = context.read<AnalyticsService>();
  final messenger = ScaffoldMessenger.of(context);
  analytics.buttonClicked('share_activity', params: {'activity_id': a.id});

  final when = timeago.format(a.startAt, allowFromNow: true);
  final message = l.tr('activity.detail.shareMessage', {
    'title': a.title,
    'place': a.placeWithCity,
    'when': when,
    'link': ActivityLinks.url(a.id),
  });

  try {
    await SharePlus.instance.share(ShareParams(
      text: message,
      subject: a.title,
      sharePositionOrigin: origin,
    ));
    analytics.actionSuccess('shareActivity', params: {'activity_id': a.id});
  } catch (_) {
    analytics.logEvent('action_failed',
        params: {'action_name': 'shareActivity', 'activity_id': a.id});
    messenger.showSnackBar(SnackBar(content: Text(l.tr('share.failed'))));
  }
}

/// Story image (Instagram / WhatsApp Status) or the plain link share.
Future<void> _showShareOptions(
  BuildContext context,
  Activity a,
  AppLocalizations l,
  Rect origin,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('share_story'),
            leading: const Icon(Icons.auto_awesome_rounded),
            title: Text(l.tr('storyCard.option')),
            subtitle: Text(l.tr('storyCard.optionHint')),
            onTap: () {
              Navigator.pop(sheet);
              StoryCardScreen.open(context, a);
            },
          ),
          ListTile(
            key: const Key('share_link'),
            leading: const Icon(Icons.link_rounded),
            title: Text(l.tr('storyCard.linkOption')),
            onTap: () {
              Navigator.pop(sheet);
              _shareActivity(context, a, l, origin);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _showActivityMenu(
  BuildContext context,
  Activity a,
  AppLocalizations l,
) async {
  final uid = context.read<AuthService>().currentUserId;
  final canLeave =
      uid != null &&
      uid != a.hostId &&
      a.isMember(uid) &&
      a.startAt.isAfter(DateTime.now());
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canLeave)
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(l.tr('activity.detail.leave.action')),
              onTap: () => Navigator.of(ctx).pop('leave'),
            ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.tr('safety.reportActivity')),
            onTap: () => Navigator.of(ctx).pop('report'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'leave') {
    await _confirmLeave(context, a, l);
  } else if (action == 'report') {
    await showReportSheet(
      context,
      target: ReportTarget.activity,
      targetId: a.id,
      activityId: a.id,
    );
  }
}

/// Hosts can edit or cancel until the hangout starts.
bool canManageActivity(Activity a) =>
    !a.cancelled && a.startAt.isAfter(DateTime.now());

Future<void> _showHostMenu(
  BuildContext context,
  Activity a,
  AppLocalizations l,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('host_edit'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.tr('activity.edit.action')),
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          ListTile(
            key: const Key('host_cancel'),
            leading: Icon(
              Icons.event_busy_outlined,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: Text(
              l.tr('activity.cancel.action'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
            onTap: () => Navigator.of(ctx).pop('cancel'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateActivityScreen(editing: a)),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.tr('activity.edit.done'))));
    }
  } else if (action == 'cancel') {
    await _confirmCancel(context, a, l);
  }
}

Future<void> _confirmCancel(
  BuildContext context,
  Activity a,
  AppLocalizations l,
) async {
  final others = a.memberIds.where((id) => id != a.hostId).length;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.tr('activity.cancel.title')),
      content: Text(switch (others) {
        0 => l.tr('activity.cancel.body'),
        1 => l.tr('activity.cancel.bodyOneMember'),
        _ => l.tr('activity.cancel.bodyMembers', {'count': others}),
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.tr('activity.cancel.keep')),
        ),
        TextButton(
          key: const Key('host_cancel_confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l.tr('activity.cancel.confirm')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<FeedController>().cancelActivity(a);
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.cancel.done'))),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.cancel.failed'))),
    );
  }
}

/// Confirms, then leaves [a] (activity + group chat).
Future<void> _confirmLeave(
  BuildContext context,
  Activity a,
  AppLocalizations l,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.tr('activity.detail.leave.title')),
      content: Text(l.tr('activity.detail.leave.body')),
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
          child: Text(l.tr('activity.detail.leave.confirm')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<FeedController>().leave(a);
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.detail.leave.done'))),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.tr('activity.detail.leave.failed'))),
    );
  }
}

/// Stretchy collapsing cover hero with glass back/share/like over the photo.
class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({
    required this.activity,
    required this.liked,
    required this.catColor,
  });

  final Activity activity;
  final bool liked;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = activity;
    final coverFallback = DecoratedBox(
      decoration: BoxDecoration(gradient: CategoryStyle.gradient(a.category)),
      child: Center(
        child: Text(a.category.emoji, style: const TextStyle(fontSize: 72)),
      ),
    );

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: catColor,
      leading: _GlassIconButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (!a.cancelled)
          _GlassIconButton(
            icon: liked ? Icons.favorite : Icons.favorite_border,
            tint: liked ? AppTheme.seed : Colors.white,
            onTap: () {
              context.read<FeedController>().toggleLike(a);
            },
          ),
        if (!a.cancelled)
          // Builder: the share sheet anchors to this button (iPad popover).
          Builder(
            builder: (button) => _GlassIconButton(
              icon: Icons.ios_share_rounded,
              onTap: () => canShareStory(a)
                  ? _showShareOptions(context, a, l, shareOriginOf(button))
                  : _shareActivity(context, a, l, shareOriginOf(button)),
            ),
          ),
        if (context.read<AuthService>().currentUserId != a.hostId)
          _GlassIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: () => _showActivityMenu(context, a, l),
          )
        else if (canManageActivity(a))
          _GlassIconButton(
            key: const Key('host_menu'),
            icon: Icons.more_horiz_rounded,
            onTap: () => _showHostMenu(context, a, l),
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Only show the inline title once mostly collapsed.
            final collapsed = constraints.maxHeight < 120;
            return AnimatedOpacity(
              opacity: collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            a.coverImageUrl?.isNotEmpty == true
                ? CoverImage(
                    source: a.coverImageUrl!,
                    errorFallback: coverFallback,
                  )
                : coverFallback,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.45, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            // Expanded title + category sit at the bottom of the photo.
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryChip(
                    emoji: a.category.emoji,
                    label: a.category.label,
                    color: catColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    a.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular frosted-glass icon button used over the cover photo.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tint = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.black.withValues(alpha: 0.28),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: tint, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White soft-shadowed card holding the when/where/going meta rows.
class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.activity,
    required this.liveCount,
    required this.l,
  });

  final Activity activity;

  /// Enrolled count excluding deleted accounts (resolved by [_EnrolledSection]).
  final int liveCount;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.softShadow(opacity: 0.07, blur: 18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          _MetaRow(
            icon: Icons.schedule_rounded,
            color: scheme.primary,
            text: l.tr('activity.startsIn', {
              'when': timeago.format(a.startAt, allowFromNow: true),
            }),
          ),
          const Divider(height: 1),
          _MetaRow(
            icon: Icons.place_outlined,
            color: scheme.primary,
            text: a.placeWithCity,
          ),
          const Divider(height: 1),
          _MetaRow(
            icon: Icons.people_alt_rounded,
            color: scheme.primary,
            text: l.tr('activity.enrolledCount', {'count': liveCount}),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// A titled section with an optional trailing widget.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// The full details body below the hero. Resolves the enrolled members'
/// profiles once, then renders the meta card ("X enrolled"), the About
/// section, the "who's going" section ("N going" + avatars), the location
/// preview and the chat button — with both enrolled counts derived from that
/// single fetch so deleted accounts (missing profile doc) are excluded
/// consistently. Deleted members still render as a "Former host/member"
/// placeholder avatar so the group history stays legible.
class _EnrolledSection extends StatefulWidget {
  const _EnrolledSection({
    required this.activity,
    required this.currentUid,
    required this.catColor,
    required this.hasChat,
    required this.joined,
    required this.l,
  });

  final Activity activity;
  final String? currentUid;
  final Color catColor;
  final bool hasChat;
  final bool joined;
  final AppLocalizations l;

  @override
  State<_EnrolledSection> createState() => _EnrolledSectionState();
}

class _EnrolledSectionState extends State<_EnrolledSection> {
  // uid -> profile, once loaded. Missing entries render an initial fallback.
  Map<String, AppUser> _profiles = const {};
  bool _loaded = false;

  /// Members to show: the actual enrolled uids. The host is listed first *only*
  /// when they're a member (keeps the avatar count equal to the member set and
  /// avoids the duplicate host that legacy docs — host not in memberIds —
  /// otherwise produced).
  List<String> get _ids {
    final members = widget.activity.memberIds;
    final host = widget.activity.hostId;
    if (members.contains(host)) {
      return [host, ...members.where((id) => id != host)];
    }
    return List<String>.from(members);
  }

  /// How many enrolled members still have a live profile doc. Deleted accounts
  /// (whose profile is gone) are excluded. Until the profiles have loaded we
  /// fall back to the raw member count so the number doesn't flash N → live.
  int get _liveCount {
    if (!_loaded) return _ids.length;
    return _ids.where((id) => _profiles.containsKey(id)).length;
  }

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void didUpdateWidget(_EnrolledSection old) {
    super.didUpdateWidget(old);
    // Re-fetch if the member set changed (e.g. someone joined while open).
    if (!_sameIds(old.activity.memberIds, widget.activity.memberIds)) {
      _loadProfiles();
    }
  }

  Future<void> _loadProfiles() async {
    final ids = _ids;
    if (ids.isEmpty) {
      setState(() => _loaded = true);
      return;
    }
    try {
      final users = await context.read<UserRepository>().fetchProfiles(ids);
      if (!mounted) return;
      setState(() {
        _profiles = {for (final u in users) u.id: u};
        _loaded = true;
      });
    } catch (_) {
      // Leave fallbacks in place on a read failure, but mark loaded so the
      // count settles rather than spinning on the raw fallback forever.
      if (mounted) setState(() => _loaded = true);
    }
  }

  bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final a = widget.activity;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaCard(activity: a, liveCount: _liveCount, l: l),
        const SizedBox(height: 20),
        _Section(
          title: l.tr('activity.detail.about'),
          child: Text(
            a.description.trim().isEmpty
                ? l.tr('activity.detail.noDescription')
                : a.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: a.description.trim().isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
              fontStyle: a.description.trim().isEmpty ? FontStyle.italic : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: l.tr('activity.detail.going'),
          trailing: Text(
            l.tr('activity.detail.goingCount', {'count': _liveCount}),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          child: _MembersRow(
            activity: a,
            currentUid: widget.currentUid,
            profiles: _profiles,
            ids: _ids,
            l: l,
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: l.tr('activity.detail.whereTitle'),
          child: _LocationCard(
            place: a.placeWithCity,
            catColor: widget.catColor,
            actionLabel: l.tr('activity.detail.directions.action'),
            onDirections: a.placeSuggestion.trim().isEmpty
                ? null
                : () => showDirectionsSheet(
                    context,
                    place: a.placeWithCity,
                    activityId: a.id,
                  ),
          ),
        ),
        if (widget.hasChat && widget.joined) ...[
          const SizedBox(height: 20),
          _OpenChatButton(
            label: l.tr('activity.detail.openChat'),
            onTap: () {
              context.read<AnalyticsService>().buttonClicked(
                'open_chat',
                params: {'activity_id': a.id},
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(chatId: a.id, title: a.title, activity: a),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Horizontal row of member avatars (real Google photo + name, fetched from the
/// users collection by [_EnrolledSection]), host first with a badge. Falls back
/// to a "Former host/member" placeholder when a member's profile is missing
/// (a deleted account or a not-yet-synced one).
class _MembersRow extends StatelessWidget {
  const _MembersRow({
    required this.activity,
    required this.currentUid,
    required this.profiles,
    required this.ids,
    required this.l,
  });

  final Activity activity;
  final String? currentUid;
  final Map<String, AppUser> profiles;
  final List<String> ids;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final id = ids[i];
          final isHost = id == activity.hostId;
          final isMe = id == currentUid;
          final profile = profiles[id];
          final label = isMe
              ? l.tr('activity.detail.you')
              : (profile != null && profile.displayName.trim().isNotEmpty)
              ? profile.displayName
              : isHost
              ? l.tr('activity.detail.formerHost')
              : l.tr('activity.detail.formerMember');
          // Tapping a member (other than yourself) opens their read-only
          // profile. Your own avatar is a no-op — you edit yours in the
          // Profile tab.
          final canRemove =
              !isMe &&
              !isHost &&
              !activity.cancelled &&
              currentUid != null &&
              currentUid == activity.hostId;
          final onTap = isMe
              ? null
              : () {
                  context.read<AnalyticsService>().buttonClicked(
                    'view_member_profile',
                    params: {'activity_id': activity.id},
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: id,
                        initialProfile: profile,
                        isHost: isHost,
                      ),
                    ),
                  );
                };
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Avatar(
                      name: profile?.displayName ?? '',
                      photoUrl: profile?.avatarUrl,
                      seed: id,
                      highlight: isHost,
                    ),
                    if (canRemove)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Semantics(
                          button: true,
                          label: l.tr('safety.removeMember'),
                          child: GestureDetector(
                            onTap: () => _confirmRemove(context, id, label),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.remove_circle_rounded,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 56,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on _MembersRow {
  Future<void> _confirmRemove(
    BuildContext context,
    String memberId,
    String name,
  ) async {
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('safety.removeConfirmTitle', {'name': name})),
        content: Text(l.tr('safety.removeConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.tr('safety.removeMember')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await feed.removeMember(activity, memberId);
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.removed', {'name': name}))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.tr('safety.actionFailed'))),
      );
    }
  }
}

/// A member avatar: the user's Google photo when available, otherwise a brand
/// gradient circle with their name's initial (uid's first char as last resort).
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.seed,
    required this.highlight,
  });

  final String name;
  final String? photoUrl;
  final String seed;
  final bool highlight;

  String get _letter {
    final fromName = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (fromName.isNotEmpty) return fromName[0].toUpperCase();
    final fromSeed = seed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return (fromSeed.isEmpty ? '?' : fromSeed[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto ? null : AppTheme.brandGradient,
        image: hasPhoto
            ? DecorationImage(
                image: CoverImage.providerFor(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
        border: highlight
            ? Border.all(color: AppTheme.accent, width: 2.5)
            : null,
        boxShadow: AppTheme.softShadow(opacity: 0.12, blur: 10),
      ),
      child: hasPhoto
          ? null
          : Text(
              _letter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
    );
  }
}

/// Location banner (faux map grid) with the place text; tapping it opens the
/// "Get directions" sheet to hand the place off to an installed maps app.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.place,
    required this.catColor,
    required this.actionLabel,
    required this.onDirections,
  });

  final String place;
  final Color catColor;
  final String actionLabel;
  final VoidCallback? onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTheme.cardRadius);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              catColor.withValues(alpha: 0.22),
              catColor.withValues(alpha: 0.10),
            ],
          ),
          border: Border.all(color: catColor.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          onTap: onDirections,
          child: SizedBox(
            height: 120,
            child: Stack(
              children: [
                // Faux map grid lines.
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter(catColor)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place, color: catColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              place,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onDirections != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: onDirections,
                            icon: const Icon(
                              Icons.directions_rounded,
                              size: 18,
                            ),
                            label: Text(actionLabel),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Outlined "open group chat" button shown to members when a chat exists.
class _OpenChatButton extends StatelessWidget {
  const _OpenChatButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Gradient Join CTA pinned to the bottom; tonal "Joined" state when a member.
class _JoinBar extends StatelessWidget {
  const _JoinBar({
    required this.joined,
    this.blockedLabel,
    required this.onJoin,
    required this.joinLabel,
    required this.joinedLabel,
    required this.leaveLabel,
    this.onLeave,
  });

  final bool joined;

  /// When set, joining isn't possible (e.g. the host removed you).
  final String? blockedLabel;
  final VoidCallback onJoin;
  final String joinLabel;
  final String joinedLabel;
  final String leaveLabel;

  /// Shown as a Leave button beside "Joined" when set.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final joinedPill = Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 20, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            joinedLabel,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: blockedLabel != null
          ? Container(
              height: 54,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(27),
              ),
              child: Text(
                blockedLabel!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : joined
          ? (onLeave == null
                ? joinedPill
                : Row(
                    children: [
                      Expanded(child: joinedPill),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: onLeave,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(leaveLabel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                      ),
                    ],
                  ))
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onJoin,
                borderRadius: BorderRadius.circular(27),
                child: Ink(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.seed.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          joinLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Frosted-glass category chip (emoji + label), mirrors the feed card chip.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$emoji $label',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
