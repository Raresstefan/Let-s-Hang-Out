import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/domain/models/message.dart';
import 'package:hangout/features/feed/feed_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late MockActivityRepository repo;
  late MockChatRepository chat;
  late FeedController c;

  setUp(() async {
    repo = MockActivityRepository();
    chat = MockChatRepository();
    c = FeedController(
      repository: repo,
      chatRepository: chat,
      authService: MockAuthService(),
      analytics: ConsoleAnalyticsService(),
      userRepository: MockUserRepository(),
    );
    await c.load();
  });

  test('editing updates the details and keeps members', () async {
    final a = c.lookup('act-coffee')!;
    final newStart = a.startAt.add(const Duration(hours: 2));
    await c.updateActivity(a.copyWith(
      title: 'Coffee & cake',
      startAt: newStart,
      category: ActivityCategory.food,
    ));
    final after = c.lookup('act-coffee')!;
    expect(after.title, 'Coffee & cake');
    expect(after.startAt, newStart);
    expect(after.category, ActivityCategory.food);
    expect(after.memberIds, a.memberIds);
    expect(after.cancelled, isFalse);
    final msgs = await chat.messages('act-coffee').first;
    expect(msgs.last.systemEvent, SystemEvent.updated);
  });

  test('cancelling hides it from Discover but keeps it reachable', () async {
    final a = c.lookup('act-coffee')!;
    await c.cancelActivity(a);
    expect(c.visibleActivities.any((x) => x.id == 'act-coffee'), isFalse);
    expect(c.lookup('act-coffee')!.cancelled, isTrue);
    expect((await repo.fetchActivities()).any((x) => x.id == 'act-coffee'),
        isFalse);
    final msgs = await chat.messages('act-coffee').first;
    expect(msgs.last.systemEvent, SystemEvent.cancelled);
  });

  test('no chat line when the host is alone', () async {
    final a = c.lookup('act-food')!; // only the host is a member
    await c.cancelActivity(a);
    final msgs = await chat.messages('act-food').first;
    expect(msgs, isEmpty);
  });
}
