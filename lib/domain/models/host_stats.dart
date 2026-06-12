/// Aggregate host reputation derived from the ratings on activities a user has
/// hosted. Shown on profiles ("★ 4.8 · 12 hangs hosted").
class HostStats {
  const HostStats({
    this.averageRating = 0,
    this.ratingCount = 0,
    this.hostedCount = 0,
  });

  /// Mean of all individual ratings across the host's activities (0 if none).
  final double averageRating;

  /// Total number of individual ratings received.
  final int ratingCount;

  /// Number of activities the user has hosted.
  final int hostedCount;

  /// Whether there's enough signal to show a star score.
  bool get hasRating => ratingCount > 0;
}
