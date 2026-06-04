import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import 'chat_repository.dart';

/// Firestore-backed group chat. Layout:
///   chats/{activityId}                         (doc id == activityId)
///     messages/{messageId}                     (subcollection, by createdAt)
class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _chatDoc(String activityId) =>
      _db.collection('chats').doc(activityId);

  CollectionReference<Map<String, dynamic>> _messagesCol(String activityId) =>
      _chatDoc(activityId).collection('messages');

  @override
  Future<void> ensureChat(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
    final doc = _chatDoc(activityId);
    final snap = await doc.get();
    if (snap.exists) return; // idempotent
    await doc.set({
      'activityId': activityId,
      'title': title,
      'memberIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
      'lastMessageText': null,
    });
  }

  @override
  Future<void> addMember(String activityId, String userId) async {
    final doc = _chatDoc(activityId);
    final snap = await doc.get();
    if (!snap.exists) return;
    await doc.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Stream<List<Message>> messages(String activityId) {
    return _messagesCol(activityId)
        .orderBy('createdAt')
        .snapshots()
        .map((q) => q.docs.map(_messageFromDoc).toList());
  }

  @override
  Future<void> sendMessage(
    String activityId, {
    required String senderId,
    required String text,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _messagesCol(activityId).add({
      'senderId': senderId,
      'text': text,
      'createdAt': now,
      'type': 'user',
    });
    await _chatDoc(activityId).update({
      'lastMessageText': text,
      'lastMessageAt': now,
    });
  }

  @override
  Future<void> sendSystemMessage(
    String activityId, {
    required String actorId,
    required String text,
  }) async {
    // senderId is the acting user's uid so the messages create rule passes
    // (membership + senderId == auth.uid); type 'system' drives rendering.
    // Deliberately does NOT bump lastMessageText/At — system lines shouldn't
    // hijack the chat-list preview.
    await _messagesCol(activityId).add({
      'senderId': actorId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'system',
    });
  }

  @override
  Future<Chat?> chatFor(String activityId) async {
    final snap = await _chatDoc(activityId).get();
    if (!snap.exists) return null;
    return _chatFromDoc(snap);
  }

  Chat _chatFromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return Chat(
      id: snap.id,
      activityId: data['activityId'] as String? ?? snap.id,
      title: data['title'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  Message _messageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      // serverTimestamp is briefly null locally before the server resolves it.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSystem: data['type'] == 'system',
    );
  }
}
