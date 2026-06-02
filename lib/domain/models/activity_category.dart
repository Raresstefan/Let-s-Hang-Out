/// Categories drive the emoji filter row in the feed and the suggestion engine.
enum ActivityCategory {
  drinks('drinks', '🍺'),
  tennis('tennis', '🎾'),
  coffee('coffee', '☕'),
  food('food', '🍔'),
  music('music', '🎵'),
  sport('sport', '⚽');

  const ActivityCategory(this.id, this.emoji);

  /// Stable id used for analytics + localization keys (`feed.filters.<id>`).
  final String id;
  final String emoji;

  static ActivityCategory fromId(String id) =>
      ActivityCategory.values.firstWhere(
        (c) => c.id == id,
        orElse: () => ActivityCategory.drinks,
      );
}
