import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/app.dart';
import 'package:hangout/core/analytics/analytics_service.dart';
import 'package:hangout/core/legal/legal.dart';
import 'package:hangout/data/auth/mock_auth_service.dart';
import 'package:hangout/data/repositories/mock_activity_repository.dart';
import 'package:hangout/data/repositories/mock_chat_repository.dart';
import 'package:hangout/data/repositories/mock_user_repository.dart';
import 'package:hangout/features/feed/widgets/activity_card.dart';
import 'package:hangout/features/feed/widgets/emoji_filter_bar.dart';

/// Builds the app fully wired with mock dependencies for widget tests. The
/// mock user has already accepted the current Terms so the gate is skipped.
HangOutApp _mockApp() => HangOutApp(
      authService: MockAuthService(),
      repository: MockActivityRepository(),
      chatRepository: MockChatRepository(),
      analytics: ConsoleAnalyticsService(),
      userRepository: MockUserRepository()
        ..acceptTerms(MockAuthService.mockUserId, kTermsVersion),
    );

void main() {
  testWidgets('app boots and renders the discover feed with activity cards',
      (tester) async {
    await tester.pumpWidget(_mockApp());

    // Initial frame shows a loading spinner, then the seeded activities load.
    // NOTE: we use timed pumps rather than pumpAndSettle — the activity cards
    // render CachedNetworkImage, whose loading keeps the scheduler busy so
    // pumpAndSettle would never settle in the test environment.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // The discover title and emoji filter bar are present.
    expect(find.text('Discover'), findsWidgets);
    expect(find.byType(EmojiFilterBar), findsOneWidget);

    // Seeded activities render as cards.
    expect(find.byType(ActivityCard), findsWidgets);
    expect(find.textContaining('Beers after work'), findsOneWidget);

    // The highlighted centre "Create" action lives in the bottom menu.
    expect(find.text('Create'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
  });

  testWidgets('tapping an emoji filter narrows the feed', (tester) async {
    await tester.pumpWidget(_mockApp());
    await tester.pumpAndSettle();

    // Find the tennis filter chip inside the emoji filter bar specifically
    // (its text is exactly the emoji), make it visible, then tap it.
    final tennisFilter = find.descendant(
      of: find.byType(EmojiFilterBar),
      matching: find.text('🎾'),
    );
    expect(tennisFilter, findsOneWidget);
    await tester.ensureVisible(tennisFilter);
    await tester.tap(tennisFilter);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tennis match'), findsOneWidget);
    expect(find.textContaining('Beers after work'), findsNothing);
  });
}
