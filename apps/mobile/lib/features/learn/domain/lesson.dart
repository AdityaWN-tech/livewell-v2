import 'breathing.dart';

/// What a content item is: a short read or an audio session (T-UI-02f).
enum LessonKind { lesson, audio }

/// The MY GOAL DO IT microhabit a lesson ends with (FR-LRN-01).
class LessonMicrohabit {
  const LessonMicrohabit({required this.title, this.minutes});

  final String title;
  final int? minutes;
}

/// A lesson or audio session in the curated library (content_items/{id},
/// approved only). The full Blueprint 6.7 metadata is still needs-product;
/// the reader uses the fields below (D-57).
class Lesson {
  const Lesson({
    required this.id,
    required this.category,
    required this.title,
    this.summary,
    this.readMinutes,
    this.kind = LessonKind.lesson,
    this.art,
    this.cards = const [],
    this.microhabit,
    this.breathing,
    this.version = 1,
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

  /// The lesson's short cards, read one at a time (content `cards`).
  final List<String> cards;

  /// The microhabit at the end of the lesson (content `microhabit`).
  final LessonMicrohabit? microhabit;

  /// An audio session that is a guided breathing pattern (content
  /// `breathing`): it plays in the built-in breathing guide.
  final BreathingPattern? breathing;

  /// The approved content version (content `version`), part of every
  /// narrated line's message id.
  final int version;

  /// Whether the app can open it now. A lesson needs its cards; an audio
  /// session needs a breathing pattern until recorded audio can play
  /// (D-57). Items that can't open are not shown, so nothing is a dead end.
  bool get opens => switch (kind) {
    LessonKind.lesson => cards.isNotEmpty,
    LessonKind.audio => breathing != null,
  };

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

/// What is saved per item (users/{uid}/content_progress/{itemId}).
class ContentProgress {
  const ContentProgress({
    required this.itemId,
    required this.progress,
    required this.completed,
    required this.updatedAt,
  });

  final String itemId;

  /// 0..1.
  final double progress;
  final bool completed;
  final DateTime updatedAt;
}
