/// A single chat message in an activity's group chat.
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isSystem = false,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  /// System messages (e.g. "X joined") aren't sent by a user.
  final bool isSystem;
}
