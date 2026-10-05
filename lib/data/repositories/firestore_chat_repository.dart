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
  Future<bool> ensureChat(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
    final doc = _chatDoc(activityId);
    final snap = await doc.get();
    if (snap.exists) return false; // idempotent
    await doc.set({
      'activityId': activityId,
      'title': title,
      'memberIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
      'lastMessageText': null,
    });
    return true;
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
  Future<void> syncChatMembers(
    String activityId, {
    required String title,
    required List<String> memberIds,
  }) async {
    final doc = _chatDoc(activityId);
    final snap = await doc.get();
    if (!snap.exists) {
      // No chat yet — create it with the activity's current members.
      await doc.set({
        'activityId': activityId,
        'title': title,
        'memberIds': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': null,
        'lastMessageText': null,
      });
      return;
    }
    // Chat exists — union any members missing from its memberIds (heals drift).
    await doc.update({'memberIds': FieldValue.arrayUnion(memberIds)});
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
    await _chatDoc(
      activityId,
    ).update({'lastMessageText': text, 'lastMessageAt': now});
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
    // Structured line: the rules verify senderId == caller, the event, and that
    // `name` matches the subject's profile — so it can't be forged. Rendering
    // builds the text from these fields. Deliberately does NOT bump
    // lastMessageText/At — system lines shouldn't hijack the chat-list preview.
    await _messagesCol(chatId).add({
      'senderId': actorId,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'system',
      'event': event.id,
      'subjectId': subjectId,
      'name': subjectName,
      if (title != null) 'title': title,
      if (activityId != null) 'activityId': activityId,
    });
  }

  @override
  Future<Chat?> chatFor(String activityId) async {
    final snap = await _chatDoc(activityId).get();
    if (!snap.exists) return null;
    return _chatFromDoc(snap);
  }

  @override
  Future<void> removeMember(String activityId, String userId) async {
    final doc = _chatDoc(activityId);
    final snap = await doc.get();
    if (!snap.exists) return;
    await doc.update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
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
      systemEvent: SystemEvent.fromId(data['event'] as String?),
      subjectName: data['name'] as String?,
      subjectTitle: data['title'] as String?,
    );
  }
}
