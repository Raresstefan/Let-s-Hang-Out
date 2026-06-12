import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_user.dart';
import '../friends/friends_controller.dart';
import 'circles_controller.dart';

/// Bottom sheet to create a circle: name, an emoji, and an initial set of
/// friends to invite. Returns the created circle's id (or null if cancelled).
class CreateCircleSheet extends StatefulWidget {
  const CreateCircleSheet({super.key});

  @override
  State<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<CreateCircleSheet> {
  final _name = TextEditingController();
  final Set<String> _invitees = {};
  String _emoji = '👥';
  bool _submitting = false;

  static const _emojiChoices = [
    '👥', '🎾', '🍺', '☕', '🍔', '🎵', '⚽', '🏀', '🎬', '🧗', '🎲', '✈️',
  ];

  @override
  void initState() {
    super.initState();
    // Ensure friends are loaded for the picker.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FriendsController>().load();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canCreate => _name.text.trim().isNotEmpty && !_submitting;

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _submitting = true);
    final circle = await context.read<CirclesController>().createCircle(
          name: _name.text.trim(),
          emoji: _emoji,
          inviteeIds: _invitees.toList(),
        );
    if (!mounted) return;
    Navigator.of(context).pop(circle?.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final friends = context.watch<FriendsController>().friends;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFBF7F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            Text(l.tr('circles.createTitle'),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                context.read<AnalyticsService>().inputTyping('circle_name');
                setState(() {});
              },
              decoration: InputDecoration(hintText: l.tr('circles.nameHint')),
            ),
            const SizedBox(height: 16),
            Text(l.tr('circles.emoji'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojiChoices)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emoji == e
                            ? AppTheme.seed.withValues(alpha: 0.18)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _emoji == e
                              ? AppTheme.seed
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l.tr('circles.selectMembers'),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.tr('circles.noFriendsToAdd'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in friends)
                      _FriendPickTile(
                        user: f,
                        selected: _invitees.contains(f.id),
                        onTap: () => setState(() {
                          _invitees.contains(f.id)
                              ? _invitees.remove(f.id)
                              : _invitees.add(f.id);
                        }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _canCreate ? _create : null,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(l.tr('circles.createCta')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendPickTile extends StatelessWidget {
  const _FriendPickTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool selected;
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
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasPhoto ? null : AppTheme.brandGradient,
          image: hasPhoto
              ? DecorationImage(
                  image: NetworkImage(user.avatarUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: hasPhoto
            ? null
            : Text(
                (name.isEmpty ? '?' : name[0]).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? AppTheme.seed : Colors.black26,
      ),
    );
  }
}
