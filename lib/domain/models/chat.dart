/// One group chat per activity. The chat id equals the activity id, which makes
/// "one chat per activity" and the join→chat link trivial and idempotent.
class Chat {
  const Chat({
    required this.id,
    required this.activityId,
    required this.title,
    required this.memberIds,
    this.lastMessageText,
    this.lastMessageAt,
  });

  final String id;
  final String activityId;
  final String title;
  final List<String> memberIds;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
}
