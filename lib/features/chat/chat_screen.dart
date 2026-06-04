import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/auth/auth_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/models/message.dart';

/// Minimal group chat: a live message list (mine vs theirs) + a send field.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.activityId,
    required this.title,
  });

  final String activityId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  ChatRepository get _chats => context.read<ChatRepository>();
  AnalyticsService get _analytics => context.read<AnalyticsService>();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = context.read<AuthService>().currentUserId;
    if (uid == null) return;
    _analytics.buttonClicked('send_message',
        params: {'activity_id': widget.activityId});
    _controller.clear();
    await _chats.sendMessage(widget.activityId, senderId: uid, text: text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final uid = context.watch<AuthService>().currentUserId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chats.messages(widget.activityId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!;
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
                    if (m.isSystem) return _SystemLine(text: m.text);
                    return _Bubble(message: m, mine: m.senderId == uid);
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        decoration: BoxDecoration(
          color: mine ? AppTheme.seed : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.softShadow(opacity: 0.06, blur: 12),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mine ? Colors.white : theme.colorScheme.onSurface,
            height: 1.3,
          ),
        ),
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
