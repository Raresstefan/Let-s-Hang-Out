import 'package:flutter/material.dart';

import '../../domain/models/activity_category.dart';

/// Per-category visual identity. Each activity category gets its own vivid color
/// so the feed and filter bar read as colorful and energetic (the "bold social"
/// direction) while staying legible. Used by the emoji filter pills and the
/// category accent on activity cards.
class CategoryStyle {
  CategoryStyle._();

  static const Map<ActivityCategory, Color> _colors = {
    ActivityCategory.drinks: Color(0xFFF4A62A), // amber
    ActivityCategory.tennis: Color(0xFF34B978), // green
    ActivityCategory.coffee: Color(0xFFA9744F), // coffee brown
    ActivityCategory.food: Color(0xFFF2683C), // orange
    ActivityCategory.music: Color(0xFF8B5CF6), // purple
    ActivityCategory.sport: Color(0xFF3B82F6), // blue
  };

  static Color color(ActivityCategory category) =>
      _colors[category] ?? const Color(0xFFFF6B5E);

  /// A subtle gradient derived from the category color for selected pills /
  /// accents.
  static LinearGradient gradient(ActivityCategory category) {
    final base = color(category);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, Color.lerp(base, Colors.black, 0.18)!],
    );
  }
}
