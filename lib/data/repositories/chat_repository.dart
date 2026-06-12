import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';

/// Group-chat backend. One chat per activity (doc id == activityId), created
/// lazily when the activity reaches 2 members (see [FeedController.join]).
abstract class ChatRepository {
  /// Create the chat for [activityId] with [memberIds] if it doesn't exist
  /// (idempotent — safe to call again on a re-join or race).
  Future<void> ensureChat(
    String activityId, {
    required String title,
    required List<String> memberIds,
  });

  /// Add a member to an existing chat (no-op if the chat is absent or the user
  /// is already a member).
  Future<void> addMember(String activityId, String userId);

  /// Ensures the chat exists and contains all of [memberIds] (creates it if
  /// missing, else unions the members in). Self-heals drift between an
  /// activity's members and its chat doc — e.g. hand-seeded activities or a
  /// join whose chat sync was missed. Call before opening a chat.
  Future<void> syncChatMembers(
    String activityId, {
    required String title,
    required List<String> memberIds,
  });

  /// Live stream of messages for a chat, oldest first.
  Stream<List<Message>> messages(String activityId);

  Future<void> sendMessage(
    String activityId, {
    required String senderId,
    required String text,
  });

  /// Posts a system line (e.g. "X joined the activity") to the chat. Rendered
  /// distinctly (centered, muted) and does not become the chat-list preview.
  /// [actorId] is the acting user's uid — used only to satisfy the message
  /// create rule (membership + senderId); rendering ignores it for system lines.
  Future<void> sendSystemMessage(
    String activityId, {
    required String actorId,
    required String text,
  });

  /// The chat for an activity, or null if none exists yet (<2 members).
  Future<Chat?> chatFor(String activityId);
}
