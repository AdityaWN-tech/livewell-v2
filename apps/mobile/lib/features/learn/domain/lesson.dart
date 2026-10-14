/// A lesson in the curated library (content_items/{id}, approved only).
/// The fields the list needs; the full Blueprint 6.7 metadata comes with the
/// lesson reader (T-LRN-01, needs-product for the exact schema).
class Lesson {
  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    this.summary,
    this.readMinutes,
  });

  final String id;

  /// Category label, for example a driver name.
  final String category;
  final String title;
  final String? summary;
  final int? readMinutes;
}
