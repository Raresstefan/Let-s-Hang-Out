import 'package:flutter/material.dart';

import '../../domain/models/activity_category.dart';

/// Per-category visual identity. Each activity category gets its own vivid color
/// so the feed and filter bar read as colorful and energetic (the "bold social"
/// direction) while staying legible. Used by the emoji filter pills and the
/// category accent on activity cards.
class CategoryStyle {
  CategoryStyle._();

  static const Map<String, Color> _featuredColors = {
    'drinks': Color(0xFFF4A62A),
    'tennis': Color(0xFF34B978),
    'padel': Color(0xFF17A673),
    'coffee': Color(0xFFA9744F),
    'food': Color(0xFFF2683C),
    'music': Color(0xFF8B5CF6),
    'sport': Color(0xFF3B82F6),
  };

  static const List<Color> _catalogPalette = [
    Color(0xFFE85D75),
    Color(0xFF7C5CE7),
    Color(0xFF2E9CDB),
    Color(0xFF12A594),
    Color(0xFFDA8A2E),
    Color(0xFFCA5A9E),
  ];

  static Color color(ActivityCategory category) {
    final featured = _featuredColors[category.id];
    if (featured != null) return featured;
    final hash = category.id.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return _catalogPalette[hash % _catalogPalette.length];
  }

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
