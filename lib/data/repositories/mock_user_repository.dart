import '../../domain/models/app_user.dart';
import '../auth/mock_auth_service.dart';
import 'user_repository.dart';

/// In-memory user profiles for mock mode. Seeds the fixed mock user and any
/// upserts made at runtime; unknown ids get a synthetic name so the who's-going
/// avatars still render a label instead of a raw uid.
class MockUserRepository implements UserRepository {
  final Map<String, AppUser> _profiles = {
    MockAuthService.mockUserId: const AppUser(
      id: MockAuthService.mockUserId,
      displayName: 'Rares',
    ),
  };

  /// Shared profile store, so [MockFriendRepository] can read/mutate the same
  /// users (e.g. append to friendIds on accept, search by name).
  Map<String, AppUser> get profiles => _profiles;

  @override
  Future<void> upsertIdentity(
    String id, {
    required String displayName,
    String? avatarUrl,
  }) async {
    final existing = _profiles[id];
    _profiles[id] = (existing ?? AppUser(id: id, displayName: displayName))
        .copyWith(
          displayName: displayName.isEmpty && existing != null
              ? existing.displayName
              : displayName,
          avatarUrl: existing?.avatarUrl ?? avatarUrl,
        );
  }

  @override
  Future<void> upsertProfile(AppUser user) async {
    _profiles[user.id] = user;
  }

  @override
  Future<AppUser?> fetchProfile(String id) async => _profiles[id];

  @override
  Future<List<AppUser>> fetchProfiles(List<String> ids) async {
    return ids
        .toSet()
        .where((id) => id.isNotEmpty)
        .map(
          (id) =>
              _profiles[id] ?? AppUser(id: id, displayName: _syntheticName(id)),
        )
        .toList();
  }

  final Map<String, int> _terms = {};

  @override
  Future<int> acceptedTermsVersion(String id) async => _terms[id] ?? 0;

  @override
  Future<void> acceptTerms(String id, int version) async {
    _terms[id] = version;
  }

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.remove(id);
  }

  String _syntheticName(String id) {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) return 'Member';
    final head = cleaned.substring(0, cleaned.length >= 6 ? 6 : cleaned.length);
    return head[0].toUpperCase() + head.substring(1);
  }
}
