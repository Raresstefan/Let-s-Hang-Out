import 'package:flutter_test/flutter_test.dart';
import 'package:hangout/domain/models/activity.dart';
import 'package:hangout/domain/models/activity_category.dart';
import 'package:hangout/domain/models/city_names.dart';

void main() {
  group('normalizeCityName', () {
    test('trims, collapses spaces and title-cases one-case input', () {
      expect(normalizeCityName('  new   york '), 'New York');
      expect(normalizeCityName('CLUJ-NAPOCA'), 'Cluj-Napoca');
      expect(normalizeCityName('amsterdam'), 'Amsterdam');
    });

    test('keeps mixed casing as typed', () {
      expect(normalizeCityName("'s-Hertogenbosch"), "'s-Hertogenbosch");
      expect(normalizeCityName('McAllen'), 'McAllen');
    });
  });

  test('cityKey ignores case, accents and punctuation', () {
    expect(cityKey('București'), cityKey('bucuresti'));
    expect(cityKey('St. Gallen'), cityKey('st gallen'));
    expect(cityKey('Zürich'), 'zurich');
    expect(cityKey('Amsterdam'), isNot(cityKey('Rotterdam')));
  });

  test('canonicalCity reuses an existing spelling', () {
    final known = ['București', 'Cluj-Napoca'];
    expect(canonicalCity('bucuresti', known), 'București');
    expect(canonicalCity('  cluj-napoca', known), 'Cluj-Napoca');
    expect(canonicalCity('amsterdam', known), 'Amsterdam');
  });

  test('cityOptionsFrom groups variants, counts and sorts busiest first', () {
    final options = cityOptionsFrom([
      'Amsterdam',
      'Cluj',
      'Bucharest',
      'cluj',
      'Cluj',
      '',
      '  ',
      'Bucharest',
    ]);
    expect(options.map((o) => o.name), ['Cluj', 'Bucharest', 'Amsterdam']);
    expect(options.map((o) => o.count), [3, 2, 1]);
  });

  test('on a spelling tie the accented native form is shown', () {
    final options = cityOptionsFrom(['Bucuresti', 'București']);
    expect(options.single.name, 'București');
    expect(options.single.count, 2);
  });

  group('Activity.placeWithCity', () {
    Activity a(String place, String city) => Activity(
          id: 'a',
          title: 't',
          description: '',
          placeSuggestion: place,
          city: city,
          startAt: DateTime(2030),
          hostId: 'h',
          category: ActivityCategory.drinks,
        );

    test('appends the city', () {
      expect(a('Old City Pub', 'Amsterdam').placeWithCity,
          'Old City Pub, Amsterdam');
    });

    test('skips the city when the place already names it', () {
      expect(a('Old City Pub, amsterdam', 'Amsterdam').placeWithCity,
          'Old City Pub, amsterdam');
    });

    test('falls back to whichever part exists', () {
      expect(a('Old City Pub', '').placeWithCity, 'Old City Pub');
      expect(a('', 'Amsterdam').placeWithCity, 'Amsterdam');
    });
  });
}
