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
  Future<void> ensureChat(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
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
  Stream<List<Message>> messages(String activityId) {
    final controller = _controllerFor(activityId);
    // Seed the new listener with whatever's already there.
    scheduleMicrotask(() => _emit(activityId));
    return controller.stream;
  }

  @override
  Future<void> sendMessage(
    String activityId, {
    required String senderId,
    required String text,
  }) async {
    final list = _messages.putIfAbsent(activityId, () => []);
    list.add(Message(
      id: _uuid.v4(),
      senderId: senderId,
      text: text,
      createdAt: DateTime.now(),
    ));
    _emit(activityId);
  }

  @override
  Future<void> sendSystemMessage(
    String activityId, {
    required String actorId,
    required String text,
  }) async {
    final list = _messages.putIfAbsent(activityId, () => []);
    list.add(Message(
      id: _uuid.v4(),
      senderId: actorId,
      text: text,
      createdAt: DateTime.now(),
      isSystem: true,
    ));
    _emit(activityId);
  }

  @override
  Future<Chat?> chatFor(String activityId) async => _chats[activityId];
}
