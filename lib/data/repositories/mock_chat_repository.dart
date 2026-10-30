import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import 'chat_repository.dart';

/// In-memory chat backend so the chat screen works fully on mock mode. Messages
/// are broadcast through a per-chat [StreamController] so the screen's
/// StreamBuilder updates live.
class MockChatRepository implements ChatRepository {
  final _uuid = const Uuid();
  final Map<String, Chat> _chats = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, StreamController<List<Message>>> _controllers = {};

  StreamController<List<Message>> _controllerFor(String activityId) =>
      _controllers.putIfAbsent(
        activityId,
        () => StreamController<List<Message>>.broadcast(),
      );

  void _emit(String activityId) {
    final list = List<Message>.unmodifiable(_messages[activityId] ?? const []);
    _controllerFor(activityId).add(list);
  }

  @override
  Future<bool> ensureChat(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
    if (_chats.containsKey(activityId)) return false;
    _chats.putIfAbsent(
      activityId,
      () => Chat(
        id: activityId,
        activityId: activityId,
        title: title,
        memberIds: List<String>.from(memberIds),
      ),
    );
    _messages.putIfAbsent(activityId, () => []);
    return true;
  }

  @override
  Future<void> addMember(String activityId, String userId) async {
    final chat = _chats[activityId];
    if (chat == null || chat.memberIds.contains(userId)) return;
    _chats[activityId] = Chat(
      id: chat.id,
      activityId: chat.activityId,
      title: chat.title,
      memberIds: [...chat.memberIds, userId],
      lastMessageText: chat.lastMessageText,
      lastMessageAt: chat.lastMessageAt,
    );
  }

  @override
  Future<void> syncChatMembers(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
    final chat = _chats[activityId];
    if (chat == null) {
      _chats[activityId] = Chat(
        id: activityId,
        activityId: activityId,
        title: title,
        memberIds: List<String>.from(memberIds),
      );
      _messages.putIfAbsent(activityId, () => []);
      return;
    }
    final merged = {...chat.memberIds, ...memberIds}.toList();
    _chats[activityId] = Chat(
      id: chat.id,
      activityId: chat.activityId,
      title: chat.title,
      memberIds: merged,
      lastMessageText: chat.lastMessageText,
      lastMessageAt: chat.lastMessageAt,
    );
  }

  @override
  Stream<List<Message>> messages(String activityId) {
    final controller = _controllerFor(activityId);
    // Seed the new listener with whatever's already there.
    scheduleMicrotask(() => _emit(activityId));
    return controller.stream;
  }

  @override
  Future<void> sendMessage(
    String activityId, {
    required String messageId,
    required String senderId,
    required String text,
  }) async {
    final list = _messages.putIfAbsent(activityId, () => []);
    if (list.any((m) => m.id == messageId)) return;
    list.add(
      Message(
        id: messageId,
        senderId: senderId,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    _emit(activityId);
  }

  @override
  Future<void> sendSystemMessage(
    String chatId, {
    required String actorId,
    required SystemEvent event,
    required String subjectId,
    required String subjectName,
    String? title,
    String? activityId,
  }) async {
    final list = _messages.putIfAbsent(chatId, () => []);
    list.add(
      Message(
        id: _uuid.v4(),
        senderId: actorId,
        text: '',
        createdAt: DateTime.now(),
        isSystem: true,
        systemEvent: event,
        subjectName: subjectName,
        subjectTitle: title,
      ),
    );
    _emit(chatId);
  }

  @override
  Future<Chat?> chatFor(String activityId) async => _chats[activityId];

  @override
  Future<void> removeMember(String activityId, String userId) async {
    final chat = _chats[activityId];
    if (chat == null || !chat.memberIds.contains(userId)) return;
    _chats[activityId] = Chat(
      id: chat.id,
      activityId: chat.activityId,
      title: chat.title,
      memberIds: chat.memberIds.where((id) => id != userId).toList(),
      lastMessageText: chat.lastMessageText,
      lastMessageAt: chat.lastMessageAt,
    );
  }
}
