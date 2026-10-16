/// What a content item is: a short read or an audio session (T-UI-02f).
enum LessonKind { lesson, audio }

/// A lesson or audio session in the curated library (content_items/{id},
/// approved only). The fields the list needs; the full Blueprint 6.7
/// metadata comes with the lesson reader (T-LRN-01, needs-product for the
/// exact schema).
class Lesson {
  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    this.summary,
    this.readMinutes,
    this.kind = LessonKind.lesson,
    this.art,
  });

  final String id;

  /// Category label, for example a driver name.
  final String category;
  final String title;
  final String? summary;

  /// Reading or listening time.
  final int? readMinutes;
  final LessonKind kind;

  /// Illustration id from assets/illustrations (content `art_id`); null
  /// picks one of the lesson placeholders.
  final String? art;

  /// The lesson art placeholders (docs/design/asset-brief.md).
  static const _arts = [
    'lesson_breathe_reset',
    'lesson_reduce_stress',
    'lesson_better_sleep',
    'lesson_move_body',
    'lesson_mindful_eating',
    'lesson_deep_breathing',
  ];

  /// [art], or a stable placeholder picked from the id.
  String get artId =>
      art ?? _arts[id.codeUnits.fold(0, (a, b) => a + b) % _arts.length];
}

/// Where the person stopped in a lesson or session ("Pick up where you left
/// off").
class LessonProgress {
  const LessonProgress({required this.lesson, required this.progress});

  final Lesson lesson;

  /// 0..1.
  final double progress;
}
