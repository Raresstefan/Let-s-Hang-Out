import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/links/activity_links.dart';
import '../../core/share/share_origin.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/activity.dart';
import 'story_card.dart';

/// Story cards are for public, live activities; circle hangouts stay private.
bool canShareStory(Activity a) => a.circleId == null && !a.cancelled;

StoryRole storyRoleFor(Activity a, String? uid) {
  if (uid != null && uid == a.hostId) return StoryRole.host;
  if (uid != null && a.isMember(uid)) return StoryRole.going;
  return StoryRole.invite;
}

/// Preview of the story card with a style picker and a Share button that
/// exports a 1080x1920 PNG to the OS share sheet.
class StoryCardScreen extends StatefulWidget {
  const StoryCardScreen({super.key, required this.activity});

  final Activity activity;

  static Future<void> open(BuildContext context, Activity a) {
    context
        .read<AnalyticsService>()
        .buttonClicked('story_card_open', params: {'activity_id': a.id});
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StoryCardScreen(activity: a),
    ));
  }

  @override
  State<StoryCardScreen> createState() => _StoryCardScreenState();
}

class _StoryCardScreenState extends State<StoryCardScreen> {
  final _boundaryKey = GlobalKey();
  late StoryCardStyle _style = widget.activity.coverImageUrl?.isNotEmpty == true
      ? StoryCardStyle.photo
      : StoryCardStyle.color;
  List<String> _initials = const [];
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadInitials();
  }

  Future<void> _loadInitials() async {
    final ids = widget.activity.memberIds.take(4).toList();
    if (ids.isEmpty) return;
    try {
      final users = await context.read<UserRepository>().fetchProfiles(ids);
      if (!mounted) return;
      setState(() {
        _initials = users
            .map((u) => initialsOf(u.displayName))
            .where((s) => s.isNotEmpty)
            .toList();
      });
    } catch (_) {
      // Initials are decoration; the card works without them.
    }
  }

  /// Renders the card at 1080 px wide (Instagram story size).
  Future<XFile> _renderPng() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final pixelRatio = 1080 / StoryCard.size.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('encode failed');
    return XFile.fromData(bytes.buffer.asUint8List(),
        mimeType: 'image/png', name: 'hangout-story.png');
  }

  /// [origin] is the tapped button (see [shareOriginOf]).
  Future<void> _share(Rect origin) async {
    final l = AppLocalizations.of(context);
    final analytics = context.read<AnalyticsService>();
    final messenger = ScaffoldMessenger.of(context);
    final a = widget.activity;
    setState(() => _sharing = true);
    var error = 'storyCard.error';
    try {
      final png = await _renderPng();
      error = 'share.failed';
      final result = await SharePlus.instance.share(ShareParams(
        files: [png],
        fileNameOverrides: const ['hangout-story.png'],
        text: l.tr('storyCard.shareText',
            {'title': a.title, 'link': ActivityLinks.url(a.id)}),
        subject: a.title,
        sharePositionOrigin: origin,
      ));
      analytics.actionSuccess('story_card_share', params: {
        'activity_id': a.id,
        'style': _style.name,
        'status': result.status.name,
      });
    } catch (_) {
      analytics.logEvent('action_failed',
          params: {'action_name': 'story_card_share', 'activity_id': a.id});
      messenger.showSnackBar(SnackBar(content: Text(l.tr(error))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = context.watch<AuthService>().currentUserId;
    final a = widget.activity;
    final hasCover = a.coverImageUrl?.isNotEmpty == true;
    final styles = [
      if (hasCover) StoryCardStyle.photo,
      StoryCardStyle.color,
      StoryCardStyle.dark,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('storyCard.title'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: StoryCard.size.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          // Fixed text scale so the exported image looks the
                          // same regardless of the phone's font size.
                          child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.noScaling),
                            child: StoryCard(
                              key: const Key('story_card'),
                              activity: a,
                              style: _style,
                              role: storyRoleFor(a, uid),
                              initials: _initials,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final s in styles)
                  ChoiceChip(
                    key: Key('story_style_${s.name}'),
                    label: Text(l.tr('storyCard.style.${s.name}')),
                    selected: _style == s,
                    onSelected: (_) => setState(() => _style = s),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
                width: double.infinity,
                // Builder: the share sheet anchors to this button (iPad popover).
                child: Builder(
                  builder: (button) => FilledButton.icon(
                    key: const Key('story_share'),
                    onPressed: _sharing
                        ? null
                        : () => _share(shareOriginOf(button)),
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(l.tr('storyCard.share')),
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
