import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/message.dart';
import '../../domain/models/report.dart';
import '../activity_details/activity_details_screen.dart';
import '../feed/feed_controller.dart';
import '../safety/safety_actions.dart';
import '../safety/safety_controller.dart';

/// Max user-message length (mirrors the Firestore rules).
const _maxMessageLength = 2000;

/// A message the user sent that the server hasn't confirmed yet.
class _Outgoing {
  _Outgoing(this.text, this.senderId) : createdAt = DateTime.now();

  final String text;
  final String senderId;
  final DateTime createdAt;
  bool failed = false;
}

/// Unconfirmed messages per chat, kept outside the screen so a failed message
/// is still there (ready to retry) after leaving and reopening the chat.
final Map<String, Map<String, _Outgoing>> _outboxes = {};

/// Minimal group chat: a live message list (mine vs theirs) + a send field.
/// Generic over the chat context — [chatId] may be an activity id or a circle
/// id (both live at `chats/{id}`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.activity,
  });

  final String chatId;
  final String title;

  /// When set, this is an activity chat — the app-bar header becomes tappable
  /// (group avatar + title) and opens the activity's details. Null for circle
  /// chats (they have their own detail screen).
  final Activity? activity;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  ChatRepository get _chats => context.read<ChatRepository>();
  AnalyticsService get _analytics => context.read<AnalyticsService>();

  Activity? get _activity {
    final initial = widget.activity;
    if (initial == null) return null;
    return context.read<FeedController>().lookup(initial.id) ?? initial;
  }

  // Created once: rebuilding (e.g. a status change) mustn't re-subscribe.
  late final Stream<List<Message>> _messages = _chats.messages(widget.chatId);

  // Live updates for an activity chat header (title / cancelled).
  StreamSubscription<Activity?>? _live;

  Map<String, _Outgoing> get _outbox =>
      _outboxes.putIfAbsent(widget.chatId, () => {});

  // Other senders' display names, looked up once each. '' marks a profile that
  // no longer exists (shown as "Someone").
  final Map<String, String> _names = {};
  final Set<String> _requested = {};

  /// Looks up the names of senders we haven't seen yet, so group messages can
  /// say who wrote them.
  void _resolveNames(List<Message> messages, String? uid) {
    final missing = {
      for (final m in messages)
        if (!m.isSystem && m.senderId != uid && !_requested.contains(m.senderId))
          m.senderId,
    };
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    context.read<UserRepository>().fetchProfiles(missing.toList()).then(
      (users) {
        if (!mounted) return;
        setState(() {
          for (final u in users) {
            _names[u.id] = u.displayName.trim();
          }
          for (final id in missing) {
            _names.putIfAbsent(id, () => '');
          }
        });
      },
      // Try again with the next update.
      onError: (Object _) => _requested.removeAll(missing),
    );
  }

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    if (a != null) _live = context.read<FeedController>().follow(a.id);
  }

  @override
  void dispose() {
    _live?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    _analytics.buttonClicked('send_message',
        params: {'chat_id': widget.chatId});
    final id = const Uuid().v4();
    // Shown immediately with a clock; the text is kept until the server
    // confirms, so a failure can be retried instead of lost.
    setState(() => _outbox[id] = _Outgoing(text, uid));
    _controller.clear();
    _deliver(id);
  }

  Future<void> _deliver(String id) async {
    final outbox = _outbox;
    final pending = outbox[id];
    if (pending == null) return;
    try {
      await _chats.sendMessage(
        widget.chatId,
        messageId: id,
        senderId: pending.senderId,
        text: pending.text,
      );
      outbox.remove(id);
    } catch (_) {
      pending.failed = true;
      _analytics.logEvent('action_failed',
          params: {'action_name': 'sendMessage', 'chat_id': widget.chatId});
    }
    if (mounted) setState(() {});
  }

  void _retry(String id) {
    final pending = _outbox[id];
    if (pending == null) return;
    _analytics.buttonClicked('retry_message',
        params: {'chat_id': widget.chatId});
    setState(() => pending.failed = false);
    _deliver(id);
  }

  Future<void> _onFailedLongPress(String id) async {
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l.tr('chat.retry')),
              onTap: () => Navigator.of(ctx).pop('retry'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l.tr('chat.deleteUnsent')),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'retry') {
      _retry(id);
    } else {
      setState(() => _outbox.remove(id));
    }
  }

  /// Server messages plus unconfirmed local ones. A confirmed copy from the
  /// server replaces the local one (same client-generated id).
  List<Message> _merge(List<Message> server) {
    final outbox = _outbox;
    final ids = <String>{};
    final merged = <Message>[];
    for (final m in server) {
      ids.add(m.id);
      final local = outbox[m.id];
      merged.add(local != null && local.failed
          ? m.withStatus(MessageStatus.failed)
          : m);
    }
    outbox.forEach((id, o) {
      if (ids.contains(id)) return;
      merged.add(Message(
        id: id,
        senderId: o.senderId,
        text: o.text,
        createdAt: o.createdAt,
        status: o.failed ? MessageStatus.failed : MessageStatus.sending,
      ));
    });
    return merged;
  }

  void _openDetails() {
    final a = _activity;
    if (a == null) return;
    _analytics.buttonClicked('open_activity_from_chat',
        params: {'activity_id': a.id});
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ActivityDetailsScreen(activityId: a.id, initialActivity: a),
    ));
  }

  /// Long-press on someone else's message: report it or block the sender.
  Future<void> _onMessageLongPress(Message m) async {
    final l = AppLocalizations.of(context);
    final users = context.read<UserRepository>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l.tr('safety.reportMessage')),
              onTap: () => Navigator.of(ctx).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text(l.tr('safety.block')),
              onTap: () => Navigator.of(ctx).pop('block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await showReportSheet(
        context,
        target: ReportTarget.message,
        targetId: m.id,
        chatId: widget.chatId,
        activityId: widget.activity?.id,
      );
      return;
    }
    String name = l.tr('chat.someone');
    try {
      final p = await users.fetchProfile(m.senderId);
      if (p != null && p.displayName.trim().isNotEmpty) name = p.displayName;
    } catch (_) {}
    if (!mounted) return;
    await confirmAndBlock(context, userId: m.senderId, name: name);
  }

  /// App-bar title. For an activity chat it's a tappable row (group avatar +
  /// title) opening the activity details, Messenger-style. Plain text otherwise.
  Widget _buildTitle(BuildContext context, AppLocalizations l) {
    final a = _activity;
    if (a == null) return Text(widget.title);
    return InkWell(
      onTap: _openDetails,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.seed.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(a.category.emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, overflow: TextOverflow.ellipsis),
                if (a.cancelled)
                  Text(
                    l.tr('activity.cancel.badge'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = context.watch<AuthService>().currentUserId;
    final safety = context.watch<SafetyController>();
    if (widget.activity != null) context.watch<FeedController>();

    return Scaffold(
      appBar: AppBar(title: _buildTitle(context, l)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messages,
              builder: (context, snap) {
                if (snap.hasError) {
                  // e.g. permission-denied (not a chat member) or offline —
                  // show a message instead of spinning forever.
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.tr('chat.unavailable'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = _merge(snap.data!);
                _resolveNames(messages, uid);
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      l.tr('chat.placeholder'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                    ),
                  );
                }
                // Keep view pinned to the newest message.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    if (m.isSystem) {
                      return _SystemLine(text: _systemText(l, m));
                    }
                    final mine = m.senderId == uid;
                    if (!mine && safety.isBlocked(m.senderId)) {
                      return _SystemLine(text: l.tr('safety.hiddenMessage'));
                    }
                    // Name the sender on the first of their consecutive
                    // messages, like group chats in WhatsApp.
                    final prev = i > 0 ? messages[i - 1] : null;
                    String? sender;
                    if (!mine &&
                        (prev == null ||
                            prev.isSystem ||
                            prev.senderId != m.senderId)) {
                      final name = _names[m.senderId];
                      if (name != null) {
                        sender = name.isEmpty ? l.tr('chat.someone') : name;
                      }
                    }
                    final bubble = _Bubble(
                      message: m,
                      mine: mine,
                      sender: sender,
                      l: l,
                    );
                    if (mine && m.status == MessageStatus.failed) {
                      return GestureDetector(
                        onTap: () => _retry(m.id),
                        onLongPress: () => _onFailedLongPress(m.id),
                        child: bubble,
                      );
                    }
                    if (mine) return bubble;
                    return GestureDetector(
                      onLongPress: () => _onMessageLongPress(m),
                      child: bubble,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            hint: l.tr('chat.placeholder'),
            onChanged: (_) => _analytics.inputTyping('chat_message'),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// Renders a system line from its structured event (legacy lines carry
/// pre-rendered [Message.text]).
String _systemText(AppLocalizations l, Message m) {
  final name = (m.subjectName?.trim().isNotEmpty ?? false)
      ? m.subjectName!.trim()
      : l.tr('chat.someone');
  switch (m.systemEvent) {
    case SystemEvent.joined:
      return l.tr('chat.systemJoined', {'name': name});
    case SystemEvent.planned:
      return l.tr('chat.systemPlanned',
          {'name': name, 'title': m.subjectTitle ?? ''});
    case SystemEvent.hostLeft:
      return l.tr('chat.systemHostLeft', {'name': name});
    case SystemEvent.creatorLeft:
      return l.tr('chat.systemCreatorLeft', {'name': name});
    case SystemEvent.left:
      return l.tr('chat.systemLeft', {'name': name});
    case SystemEvent.updated:
      return l.tr('chat.systemUpdated', {'name': name});
    case SystemEvent.cancelled:
      return l.tr('chat.systemCancelled', {'name': name});
    case null:
      return m.text;
  }
}

/// A centered, muted system line (e.g. "Alex joined the activity"). Visually
/// distinct from the left/right user bubbles so it reads as chat scaffolding.
class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Sender-name colours, all at least 4.5:1 on the white bubble. No red: that
/// marks unsent messages.
final _senderColors = [
  Colors.pink.shade700,
  Colors.purple.shade700,
  Colors.deepPurple.shade600,
  Colors.indigo.shade600,
  Colors.blue.shade800,
  Colors.cyan.shade900,
  Colors.teal.shade700,
  Colors.green.shade800,
  Colors.deepOrange.shade900,
  Colors.brown.shade600,
];

/// The same colour for a person on every device (String.hashCode isn't
/// guaranteed to be stable across platforms).
Color _senderColor(String uid) {
  var h = 0;
  for (final c in uid.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _senderColors[h % _senderColors.length];
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.l,
    this.sender,
  });

  final Message message;
  final bool mine;
  final AppLocalizations l;

  /// Shown above someone else's message when it starts a run of theirs.
  final String? sender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = mine && message.status == MessageStatus.failed;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      decoration: BoxDecoration(
        color: mine
            ? AppTheme.seed.withValues(alpha: failed ? 0.55 : 1)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow(opacity: 0.06, blur: 12),
      ),
      child: mine
          ? Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: [
                Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                if (!failed) _StatusIcon(status: message.status, l: l),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      sender!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _senderColor(message.senderId),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ],
            ),
    );
    if (!failed) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }
    final error = theme.colorScheme.error;
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: l.tr('chat.notSent'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_rounded, color: error, size: 20),
                const SizedBox(width: 6),
                bubble,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: Text(
                l.tr('chat.notSent'),
                style: theme.textTheme.labelSmall?.copyWith(color: error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clock while sending, one check once the server has the message.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.l});

  final MessageStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final sending = status == MessageStatus.sending;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Icon(
        sending ? Icons.schedule_rounded : Icons.done_rounded,
        size: 14,
        color: Colors.white.withValues(alpha: 0.8),
        semanticLabel:
            l.tr(sending ? 'chat.statusSending' : 'chat.statusSent'),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maxMessageLength),
                ],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: hint),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSend,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
