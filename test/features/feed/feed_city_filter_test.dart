import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/features/feed/feed_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FeedController> _controller(MockActivityRepository repo) async {
  final c = FeedController(
    repository: repo,
    chatRepository: MockChatRepository(),
    authService: MockAuthService(),
    analytics: ConsoleAnalyticsService(),
    userRepository: MockUserRepository(),
  );
  await c.load();
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('city options come only from cities that have activities', () async {
    final c = await _controller(MockActivityRepository());
    // Seed: 2 in Bucharest, 1 in Cluj-Napoca, 1 in Amsterdam.
    expect(c.cityOptions.map((o) => o.name),
        ['Bucharest', 'Amsterdam', 'Cluj-Napoca']);
    expect(c.cityOptions.first.count, 2);
  });

  test('a newly created city shows up and old cityless ones are ignored',
      () async {
    final repo = MockActivityRepository();
    Activity draft(String city) => Activity(
          id: '',
          title: 'Run',
          description: '',
          placeSuggestion: 'Park',
          city: city,
          startAt: DateTime.now().add(const Duration(days: 1)),
          hostId: 'someone',
          category: ActivityCategory.sport,
        );
    await repo.createActivity(draft('Lisbon'));
    await repo.createActivity(draft(''));
    final c = await _controller(repo);
    expect(c.cityOptions.map((o) => o.name), contains('Lisbon'));
    expect(c.cityOptions.length, 4);
    expect(c.discoverableCount, 5); // the cityless one isn't counted
  });

  test('selecting a city narrows the feed (accent/case-insensitive)',
      () async {
    final c = await _controller(MockActivityRepository());
    c.setCity('Bucuresti');
    expect(c.visibleActivities, isEmpty); // "bucuresti" ≠ "bucharest"
    c.setCity('bucharest');
    expect(c.visibleActivities.map((a) => a.city).toSet(), {'Bucharest'});
    expect(c.visibleActivities.length, 2);
    c.setCity(null);
    expect(c.visibleActivities.length, 4);
  });

  test('city combines with the category filter', () async {
    final c = await _controller(MockActivityRepository());
    c.setCity('Bucharest');
    c.toggleFilter(ActivityCategory.coffee);
    expect(c.visibleActivities.map((a) => a.id), ['act-coffee']);
  });

  test('the chosen city is remembered across launches', () async {
    final first = await _controller(MockActivityRepository());
    first.setCity('Amsterdam');
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FeedController.cityPrefKey), 'Amsterdam');

    final second = await _controller(MockActivityRepository());
    expect(second.city, 'Amsterdam');
    expect(second.visibleActivities.map((a) => a.id), ['act-food']);

    second.setCity(null);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(FeedController.cityPrefKey), isNull);
  });
}
