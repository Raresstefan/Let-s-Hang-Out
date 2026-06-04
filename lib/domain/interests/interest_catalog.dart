/// A single selectable interest in the catalog.
class Interest {
  const Interest(this.id, this.emoji, this.label);

  /// Stable id stored on the user's profile (`AppUser.interests`). Custom
  /// user-added interests are stored as their raw text and won't appear here.
  final String id;
  final String emoji;
  final String label;
}

/// A titled group of related interests, for the Tinder-style selection sheet.
class InterestGroup {
  const InterestGroup(this.title, this.interests);
  final String title;
  final List<Interest> interests;
}

/// Curated, grouped interest catalog. Intentionally decoupled from
/// [ActivityCategory] (which drives the 6-emoji feed filter) — interests are a
/// richer, free-form signal for who a person is and what they'd hang out for.
/// Selecting many is frictionless; users may also add their own ("Other").
class InterestCatalog {
  const InterestCatalog._();

  static const List<InterestGroup> groups = [
    InterestGroup('Sports & Active', [
      Interest('tennis', '🎾', 'Tennis'),
      Interest('padel', '🎾', 'Padel'),
      Interest('football', '⚽', 'Football'),
      Interest('basketball', '🏀', 'Basketball'),
      Interest('running', '🏃', 'Running'),
      Interest('cycling', '🚴', 'Cycling'),
      Interest('gym', '🏋️', 'Gym'),
      Interest('hiking', '🥾', 'Hiking'),
      Interest('swimming', '🏊', 'Swimming'),
      Interest('yoga', '🧘', 'Yoga'),
      Interest('climbing', '🧗', 'Climbing'),
      Interest('skiing', '⛷️', 'Skiing'),
    ]),
    InterestGroup('Food & Drink', [
      Interest('coffee', '☕', 'Coffee'),
      Interest('brunch', '🥞', 'Brunch'),
      Interest('drinks', '🍺', 'Drinks'),
      Interest('wine', '🍷', 'Wine'),
      Interest('cocktails', '🍸', 'Cocktails'),
      Interest('foodie', '🍔', 'Foodie'),
      Interest('cooking', '👨‍🍳', 'Cooking'),
      Interest('baking', '🧁', 'Baking'),
      Interest('bbq', '🍖', 'BBQ'),
    ]),
    InterestGroup('Going Out', [
      Interest('clubbing', '🕺', 'Clubbing'),
      Interest('live_music', '🎤', 'Live music'),
      Interest('concerts', '🎫', 'Concerts'),
      Interest('festivals', '🎪', 'Festivals'),
      Interest('karaoke', '🎙️', 'Karaoke'),
      Interest('bars', '🍻', 'Bars'),
      Interest('comedy', '😂', 'Comedy'),
    ]),
    InterestGroup('Creative', [
      Interest('music', '🎵', 'Music'),
      Interest('photography', '📷', 'Photography'),
      Interest('painting', '🎨', 'Painting'),
      Interest('writing', '✍️', 'Writing'),
      Interest('dancing', '💃', 'Dancing'),
      Interest('film', '🎬', 'Film'),
      Interest('theatre', '🎭', 'Theatre'),
      Interest('crafts', '🧵', 'Crafts'),
    ]),
    InterestGroup('Chill & Social', [
      Interest('board_games', '🎲', 'Board games'),
      Interest('video_games', '🎮', 'Video games'),
      Interest('reading', '📚', 'Reading'),
      Interest('museums', '🏛️', 'Museums'),
      Interest('travel', '✈️', 'Travel'),
      Interest('picnics', '🧺', 'Picnics'),
      Interest('beach', '🏖️', 'Beach'),
      Interest('pets', '🐶', 'Pets'),
      Interest('volunteering', '🤝', 'Volunteering'),
    ]),
    InterestGroup('Mind & Tech', [
      Interest('tech', '💻', 'Tech'),
      Interest('startups', '🚀', 'Startups'),
      Interest('science', '🔬', 'Science'),
      Interest('languages', '🗣️', 'Languages'),
      Interest('chess', '♟️', 'Chess'),
      Interest('podcasts', '🎧', 'Podcasts'),
    ]),
  ];

  /// Flat lookup of catalog interests by id.
  static final Map<String, Interest> byId = {
    for (final g in groups)
      for (final i in g.interests) i.id: i,
  };

  /// The display label + emoji for a stored interest id. Catalog ids resolve to
  /// their curated label/emoji; custom (user-added) interests fall back to their
  /// raw text with a generic sparkle emoji.
  static Interest resolve(String id) =>
      byId[id] ?? Interest(id, '✨', _humanize(id));

  static String _humanize(String id) {
    if (id.isEmpty) return id;
    final spaced = id.replaceAll('_', ' ').trim();
    return spaced.isEmpty
        ? id
        : spaced[0].toUpperCase() + spaced.substring(1);
  }
}
