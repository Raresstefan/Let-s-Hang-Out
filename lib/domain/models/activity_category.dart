import '../interests/interest_catalog.dart';

class ActivityCategoryGroup {
  const ActivityCategoryGroup(this.label, this.categories);

  final String label;
  final List<ActivityCategory> categories;
}

/// A stable activity category backed by the shared social-interest catalog.
///
/// Equality uses [id] so categories reconstructed from Firestore behave like
/// their catalog instances. Unknown IDs are preserved with a generic visual
/// instead of being misclassified as another category.
class ActivityCategory {
  const ActivityCategory(this.id, this.emoji, this.label);

  final String id;
  final String emoji;
  final String label;

  static final List<ActivityCategoryGroup> groups = _buildGroups();

  static final List<ActivityCategory> values = [
    for (final group in groups) ...group.categories,
  ];

  static final Map<String, ActivityCategory> _byId = {
    for (final category in values) category.id: category,
  };

  static final List<ActivityCategory> featured = [
    drinks,
    tennis,
    padel,
    coffee,
    food,
    music,
    sport,
  ];

  static ActivityCategory get drinks => fromId('drinks');
  static ActivityCategory get tennis => fromId('tennis');
  static ActivityCategory get padel => fromId('padel');
  static ActivityCategory get coffee => fromId('coffee');
  static ActivityCategory get food => fromId('food');
  static ActivityCategory get music => fromId('music');
  static ActivityCategory get sport => fromId('sport');

  bool get isFeatured => featured.contains(this);

  static ActivityCategory fromId(String id) {
    final normalized = id.trim().toLowerCase();
    return _byId[normalized] ??
        ActivityCategory(normalized, '✨', _humanize(normalized));
  }

  static List<ActivityCategoryGroup> _buildGroups() {
    return [
      for (final group in InterestCatalog.groups)
        ActivityCategoryGroup(group.title, [
          if (group.title == 'Sports & Active')
            const ActivityCategory('sport', '⚽', 'Sport'),
          for (final interest in group.interests)
            if (interest.id == 'foodie')
              const ActivityCategory('food', '🍔', 'Food')
            else
              ActivityCategory(interest.id, interest.emoji, interest.label),
        ]),
    ];
  }

  static String _humanize(String id) {
    if (id.isEmpty) return 'Other';
    final spaced = id.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return 'Other';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ActivityCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
