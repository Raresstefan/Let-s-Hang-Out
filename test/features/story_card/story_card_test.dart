import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/features/story_card/story_card.dart';
import 'package:hangout/features/story_card/story_card_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

Activity _activity({String? circleId}) => Activity(
      id: 'abc123',
      title: 'Sunset run by the lake',
      description: '',
      placeSuggestion: 'Herastrau Park',
      city: 'Bucharest',
      startAt: DateTime(2030, 6, 1, 19, 30),
      hostId: 'host',
      category: ActivityCategory.sport,
      memberIds: const ['host', 'm1', 'm2'],
      circleId: circleId,
    );

Future<void> _pumpCard(WidgetTester tester, StoryRole role,
    {StoryCardStyle style = StoryCardStyle.color}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en', 'US'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', 'US')],
    home: Center(
      child: FittedBox(
        child: StoryCard(
          activity: _activity(),
          style: style,
          role: role,
          initials: const ['AP', 'M'],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => rootBundle.clear());

  testWidgets('host card shows headline, title, place+city, count and QR',
      (tester) async {
    await _pumpCard(tester, StoryRole.host);
    expect(find.text("I'M HOSTING"), findsOneWidget);
    expect(find.text('Sunset run by the lake'), findsOneWidget);
    expect(find.text('Herastrau Park, Bucharest'), findsOneWidget);
    expect(find.text('3 going'), findsOneWidget);
    expect(find.text('AP'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('hang-out-129b5.web.app/a/abc123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member card says "I\'m going to"; dark style renders',
      (tester) async {
    await _pumpCard(tester, StoryRole.going, style: StoryCardStyle.dark);
    expect(find.text("I'M GOING TO"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('role and visibility rules', () {
    final a = _activity();
    expect(storyRoleFor(a, 'host'), StoryRole.host);
    expect(storyRoleFor(a, 'm1'), StoryRole.going);
    expect(storyRoleFor(a, 'stranger'), StoryRole.invite);
    expect(storyRoleFor(a, null), StoryRole.invite);
    expect(canShareStory(a), isTrue);
    expect(canShareStory(_activity(circleId: 'c1')), isFalse);
  });

  test('initials', () {
    expect(initialsOf('Ana Pop'), 'AP');
    expect(initialsOf('mihai'), 'M');
    expect(initialsOf('  '), '');
  });
}
