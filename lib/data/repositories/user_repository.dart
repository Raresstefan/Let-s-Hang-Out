import '../../domain/models/app_user.dart';

/// Abstraction over user-profile persistence. Profiles are written on sign-in
/// (so other people can see a member's real name + photo) and read by uid where
/// the app needs to render who someone is (e.g. the who's-going avatars) or to
/// hydrate the owner's editable profile (bio + interests).
abstract class UserRepository {
  /// Writes only the identity fields (display name + avatar) for [id]. Used at
  /// sign-in so it never clobbers the user's saved [AppUser.bio] /
  /// [AppUser.interests], which are edited separately via [upsertProfile].
  Future<void> upsertIdentity(
    String id, {
    required String displayName,
    String? avatarUrl,
  });

  /// Creates or updates the full editable profile for [user] (keyed by
  /// [AppUser.id]) — including bio + interests.
  Future<void> upsertProfile(AppUser user);

  /// The profile for [id], or null if none is stored yet.
  Future<AppUser?> fetchProfile(String id);

  /// Fetches the profiles for [ids]. Missing ids are simply absent from the
  /// result — callers fall back to an initial avatar for those.
  Future<List<AppUser>> fetchProfiles(List<String> ids);

  /// The community-rules/terms version [id] last accepted (0 = never).
  Future<int> acceptedTermsVersion(String id);

  /// Records that [id] accepted terms [version] (with a server timestamp).
  Future<void> acceptTerms(String id, int version);

  /// Deletes the stored profile for [id]. Used when the user deletes their
  /// account; does not touch activities/chats/friendships owned by other
  /// users — those simply keep referencing the now-deleted uid.
  Future<void> deleteProfile(String id);
}
