import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/core/l10n/app_localizations.dart';
import 'package:hangout/features/categories/activity_category_picker.dart';

void main() {
  testWidgets('searches the shared catalog and returns a category', (
    tester,
  ) async {
    var selected = 'None';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en', 'US')],
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  Text(selected),
                  FilledButton(
                    onPressed: () async {
                      final category = await showActivityCategoryPicker(
                        context,
                      );
                      if (category != null) {
                        setState(() => selected = category.label);
                      }
                    },
                    child: const Text('Choose'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'board');
    await tester.pumpAndSettle();

    expect(find.text('Board games'), findsOneWidget);
    await tester.tap(find.text('Board games'));
    await tester.pumpAndSettle();

    expect(find.text('Board games'), findsOneWidget);
  });
}
