/// Kinds of structured system lines. Stored as [SystemEvent.id] in the
/// message's `event` field and verified by the Firestore rules, so a member
/// can't forge arbitrary "system" text — the client renders the line from the
/// event + the stored subject name/title.
enum SystemEvent {
  joined('joined'),
  planned('planned'),
  hostLeft('hostLeft'),
  creatorLeft('creatorLeft');

  const SystemEvent(this.id);

  final String id;

  static SystemEvent? fromId(String? id) {
    for (final e in values) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// A single chat message in an activity's group chat.
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isSystem = false,
    this.systemEvent,
    this.subjectName,
    this.subjectTitle,
  });

  final String id;
  final String senderId;

  /// User-message text. For legacy system lines (no [systemEvent]) this holds
  /// the pre-rendered line; structured system lines leave it empty.
  final String text;
  final DateTime createdAt;

  /// System messages (e.g. "X joined") aren't sent by a user.
  final bool isSystem;

  /// The structured event of a system line (null for user/legacy messages).
  final SystemEvent? systemEvent;

  /// Display name of the user the system line is about.
  final String? subjectName;

  /// Hangout title for [SystemEvent.planned].
  final String? subjectTitle;
}
