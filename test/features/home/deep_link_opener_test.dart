import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/app.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/core/legal/legal.dart';
import 'package:hangout/core/links/deep_link_service.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/features/activity_details/activity_details_screen.dart';

void main() {
  late StreamController<Uri> links;

  HangOutApp app() => HangOutApp(
        authService: MockAuthService(),
        repository: MockActivityRepository(),
        chatRepository: MockChatRepository(),
        analytics: ConsoleAnalyticsService(),
        userRepository: MockUserRepository()
          ..acceptTerms(MockAuthService.mockUserId, kTermsVersion),
        deepLinks: DeepLinkService(links.stream),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
  }

  setUp(() {
    // rootBundle caches the strings file as a future bound to the previous
    // test's fake clock, which never resolves in the next test.
    rootBundle.clear();
    links = StreamController<Uri>();
  });
  tearDown(() => links.close());

  testWidgets('a link received while running opens the activity',
      (tester) async {
    await start(tester);
    expect(find.byType(ActivityDetailsScreen), findsNothing);

    links.add(Uri.parse('https://hang-out-129b5.web.app/a/act-beers'));
    await settle(tester);

    expect(find.byType(ActivityDetailsScreen), findsOneWidget);
    expect(find.textContaining('Beers after work'), findsWidgets);
  });

  testWidgets('a cold-start link waits for the home screen', (tester) async {
    links.add(Uri.parse('hangout://activity/act-beers'));
    await start(tester);

    expect(find.byType(ActivityDetailsScreen), findsOneWidget);
  });

  testWidgets('an unknown activity shows a message instead', (tester) async {
    await start(tester);

    links.add(Uri.parse('https://hang-out-129b5.web.app/a/nope'));
    await settle(tester);

    expect(find.byType(ActivityDetailsScreen), findsNothing);
    expect(find.textContaining("isn't available"), findsOneWidget);
  });

  testWidgets('non-activity links are ignored', (tester) async {
    await start(tester);

    links.add(Uri.parse('https://example.com/a/act-beers'));
    await settle(tester);

    expect(find.byType(ActivityDetailsScreen), findsNothing);
  });
}
