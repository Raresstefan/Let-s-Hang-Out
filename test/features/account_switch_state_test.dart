import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/data/auth/auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_circle_repository.dart';
import 'package:hangout/data/repositories/mock_friend_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/domain/models/app_user.dart';
import 'package:hangout/domain/models/circle.dart';
import 'package:hangout/domain/models/friend_request.dart';
import 'package:hangout/features/circles/circles_controller.dart';
import 'package:hangout/features/feed/feed_controller.dart';
import 'package:hangout/features/friends/friends_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-wide controllers outlive sign-out (logout, or delete account), so
/// whoever signs in next in the same process must get their own data and live
/// streams — never the previous account's.

class _Auth extends AuthService {
  String? _uid;

  void signInAs(String uid) {
    _uid = uid;
    notifyListeners();
  }

  @override
  String? get currentUserId => _uid;
  @override
  String? get displayName => _uid;
  @override
  String? get photoUrl => null;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {
    _uid = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() => signOut();
}

/// One server-side stream per subscription, recording who subscribed. [kill]
/// mimics Firestore after sign-out: a permission-denied error, then done.
class _Streams<T> {
  final List<String> calls = [];
  final Map<String, StreamController<T>> _latest = {};

  Stream<T> open(String uid) {
    calls.add(uid);
    final c = StreamController<T>();
    _latest[uid] = c;
    return c.stream;
  }

  void emit(String uid, T value) => _latest[uid]!.add(value);

  bool listening(String uid) => _latest[uid]!.hasListener;

  Future<void> kill(String uid) async {
    final c = _latest[uid]!;
    if (!c.hasListener) return;
    c.addError(StateError('permission-denied'));
    await c.close();
  }
}

class _Friends extends MockFriendRepository {
  _Friends(super.users);
  final requests = _Streams<List<FriendRequest>>();

  @override
  Stream<List<FriendRequest>> incomingRequests(String uid) =>
      requests.open(uid);

  @override
  Future<List<FriendRequest>> outgoingRequests(String uid) async => const [];
}

class _Circles extends MockCircleRepository {
  _Circles(super.chats);
  final circles = _Streams<List<Circle>>();
  final invites = _Streams<List<CircleInvite>>();

  @override
  Stream<List<Circle>> myCircles(String uid) => circles.open(uid);

  @override
  Stream<List<CircleInvite>> incomingInvites(String uid) => invites.open(uid);
}

FriendRequest _request(String from, String to) => FriendRequest(
    id: '${from}_$to', fromId: from, toId: to, status: 'pending');

CircleInvite _invite(String circleId, String to) => CircleInvite(
      id: '${circleId}_$to',
      circleId: circleId,
      circleName: circleId,
      fromId: 'someone',
      toId: to,
      status: 'pending',
    );

Circle _circle(String id, String member) =>
    Circle(id: id, name: id, creatorId: member, memberIds: [member]);

Future<MockUserRepository> _users() async {
  final users = MockUserRepository();
  await users.upsertProfile(
      const AppUser(id: 'alice', displayName: 'Alice', friendIds: ['bob']));
  await users.upsertProfile(const AppUser(id: 'bob', displayName: 'Bob'));
  await users.upsertProfile(const AppUser(id: 'carol', displayName: 'Carol'));
  return users;
}

void main() {
  late _Auth auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _Auth()..signInAs('alice');
  });

  group('FriendsController', () {
    late _Friends repo;
    late FriendsController c;

    setUp(() async {
      repo = _Friends(await _users());
      c = FriendsController(
        friendRepository: repo,
        userRepository: await _users(),
        authService: auth,
        analytics: ConsoleAnalyticsService(),
      );
      await pumpEventQueue();
      repo.requests.emit('alice', [_request('bob', 'alice')]);
      await pumpEventQueue();
      expect(c.friends.map((u) => u.id), ['bob']);
      expect(c.incomingCount, 1);
    });

    tearDown(() => c.dispose());

    test('the next account sees none of the previous account\'s data',
        () async {
      await auth.deleteAccount();
      await repo.requests.kill('alice');
      expect(c.friends, isEmpty);
      expect(c.incoming, isEmpty);

      auth.signInAs('carol');
      await pumpEventQueue();
      expect(c.friends, isEmpty);
      expect(c.incoming, isEmpty);
    });

    test('incoming requests stay live after signing in again', () async {
      await auth.signOut();
      await repo.requests.kill('alice');

      auth.signInAs('carol');
      await pumpEventQueue();
      repo.requests.emit('carol', [_request('bob', 'carol')]);
      await pumpEventQueue();
      expect(c.incoming.single.request.toId, 'carol');
      expect(repo.requests.listening('alice'), isFalse);

      await auth.signOut();
      await repo.requests.kill('carol');
      auth.signInAs('alice');
      await pumpEventQueue();
      repo.requests.emit('alice', [_request('carol', 'alice')]);
      await pumpEventQueue();
      expect(c.incoming.single.request.fromId, 'carol');
      expect(repo.requests.calls, ['alice', 'carol', 'alice']);
    });
  });

  group('CirclesController', () {
    late _Circles repo;
    late CirclesController c;

    setUp(() async {
      repo = _Circles(MockChatRepository());
      c = CirclesController(
        circleRepository: repo,
        chatRepository: MockChatRepository(),
        userRepository: await _users(),
        authService: auth,
        analytics: ConsoleAnalyticsService(),
      );
      repo.circles.emit('alice', [_circle('trivia', 'alice')]);
      repo.invites.emit('alice', [_invite('chess', 'alice')]);
      await pumpEventQueue();
      expect(c.myCircles.map((x) => x.id), ['trivia']);
      expect(c.incomingCount, 1);
    });

    tearDown(() => c.dispose());

    test('the next account gets its own live circles and invites only',
        () async {
      await auth.deleteAccount();
      await repo.circles.kill('alice');
      await repo.invites.kill('alice');
      expect(c.myCircles, isEmpty);
      expect(c.incoming, isEmpty);

      auth.signInAs('carol');
      await pumpEventQueue();
      expect(c.myCircles, isEmpty);
      repo.circles.emit('carol', [_circle('book-club', 'carol')]);
      repo.invites.emit('carol', [_invite('padel', 'carol')]);
      await pumpEventQueue();
      expect(c.myCircles.map((x) => x.id), ['book-club']);
      expect(c.incoming.single.invite.toId, 'carol');
      expect(repo.circles.calls, ['alice', 'carol']);
      expect(repo.invites.calls, ['alice', 'carol']);
    });
  });

  test('FeedController drops the previous account\'s badges and cached copies',
      () async {
    final c = FeedController(
      repository: MockActivityRepository(),
      chatRepository: MockChatRepository(),
      authService: auth,
      analytics: ConsoleAnalyticsService(),
      userRepository: await _users(),
    );
    addTearDown(c.dispose);
    await c.load();
    final bobGoing = Activity(
      id: 'a1',
      title: 'Run',
      description: '',
      placeSuggestion: 'Park',
      city: 'Bucharest',
      startAt: DateTime.now().add(const Duration(days: 1)),
      hostId: 'bob',
      category: ActivityCategory.sport,
      memberIds: const ['bob'],
    );
    expect(c.friendsGoing(bobGoing), 1);
    final circleOnly = Activity(
      id: 'circle-only',
      title: 'Trivia',
      description: '',
      placeSuggestion: 'Pub',
      city: 'Bucharest',
      startAt: DateTime.now().add(const Duration(days: 2)),
      hostId: 'alice',
      category: ActivityCategory.drinks,
      memberIds: const ['alice'],
    );
    c.applyRemote([circleOnly]);
    expect(c.lookup('circle-only'), isNotNull);

    await auth.signOut();
    expect(c.friendsGoing(bobGoing), 0);
    expect(c.lookup('circle-only'), isNull);

    auth.signInAs('carol');
    await pumpEventQueue();
    expect(c.friendsGoing(bobGoing), 0);
    expect(c.lookup('circle-only'), isNull);
  });
}
