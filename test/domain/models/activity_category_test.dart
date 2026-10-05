import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/domain/interests/interest_catalog.dart';
import 'package:hangout/domain/models/activity_category.dart';

void main() {
  test('featured categories include Padel', () {
    expect(
      ActivityCategory.featured.map((category) => category.id),
      contains('padel'),
    );
  });

  test('activity categories reuse the full interest catalog', () {
    final activityIds = ActivityCategory.values
        .map((category) => category.id)
        .toSet();

    for (final interestId in InterestCatalog.byId.keys) {
      final expectedId = interestId == 'foodie' ? 'food' : interestId;
      expect(activityIds, contains(expectedId));
    }
  });

  test('unknown IDs are preserved with a generic visual', () {
    final category = ActivityCategory.fromId('future_activity');

    expect(category.id, 'future_activity');
    expect(category.label, 'Future activity');
    expect(category.emoji, '✨');
    expect(category, isNot(ActivityCategory.drinks));
  });

  test('categories compare by stable ID', () {
    expect(
      ActivityCategory.fromId('tennis'),
      ActivityCategory.fromId('tennis'),
    );
  });
}
