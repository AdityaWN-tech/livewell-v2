/// Lessons and courses written by staff Admins (D-113/D-114). Stored where
/// the app already reads them: lessons in content_items, courses in courses.
library;

/// draft -> pending (submitted) -> approved (by a different admin) -> live.
enum ReviewState {
  draft('draft', 'Draft'),
  pending('pending', 'Waiting for review'),
  approved('approved', 'Live'),
  rejected('rejected', 'Sent back'),
  retired('retired', 'Retired');

  const ReviewState(this.id, this.label);
  final String id;
  final String label;

  static ReviewState of(Object? v) =>
      values.firstWhere((s) => s.id == v, orElse: () => ReviewState.draft);
}

/// A lesson (type lesson) or a breathing session (type audio).
class LessonDoc {
  const LessonDoc({
    this.id,
    this.audio = false,
    this.title = '',
    this.category = '',
    this.summary = '',
    this.cards = const [],
    this.microhabitTitle = '',
    this.microhabitMinutes,
    this.readMinutes,
    this.breathing,
    this.state = ReviewState.draft,
    this.authorUid = '',
    this.reviewedBy,
    this.version = 1,
  });

  final String? id;
  final bool audio;
  final String title;
  final String category;
  final String summary;
  final List<String> cards;
  final String microhabitTitle;
  final int? microhabitMinutes;
  final int? readMinutes;

  /// box, calm or sleep (breathing sessions).
  final String? breathing;
  final ReviewState state;
  final String authorUid;
  final String? reviewedBy;
  final int version;

  /// Everything a reader sees, for the content check.
  String get allText => [
    title,
    summary,
    ...cards,
    microhabitTitle,
  ].where((s) => s.trim().isNotEmpty).join('\n');

  /// The editable fields, as stored (review fields are set separately).
  Map<String, Object> contentFields() => {
    'type': audio ? 'audio' : 'lesson',
    'title': title.trim(),
    'category': category.trim(),
    if (summary.trim().isNotEmpty) 'summary': summary.trim(),
    'cards': [
      for (final c in cards)
        if (c.trim().isNotEmpty) c.trim(),
    ],
    if (microhabitTitle.trim().isNotEmpty)
      'microhabit': {
        'title': microhabitTitle.trim(),
        'minutes': ?microhabitMinutes,
      },
    'read_minutes': ?readMinutes,
    'breathing': ?breathing,
  };
}

/// Who sees a course.
enum CourseVisibility { all, selected }

class CourseDoc {
  const CourseDoc({
    this.id,
    this.title = '',
    this.category = '',
    this.summary = '',
    this.lessonIds = const [],
    this.visibility = CourseVisibility.all,
    this.allowedEmails = const [],
    this.state = ReviewState.draft,
    this.authorUid = '',
    this.reviewedBy,
    this.version = 1,
  });

  final String? id;
  final String title;
  final String category;
  final String summary;
  final List<String> lessonIds;
  final CourseVisibility visibility;
  final List<String> allowedEmails;
  final ReviewState state;
  final String authorUid;
  final String? reviewedBy;
  final int version;

  String get allText => [title, summary].join('\n');

  Map<String, Object> contentFields() => {
    'title': title.trim(),
    'category': category.trim(),
    if (summary.trim().isNotEmpty) 'summary': summary.trim(),
    'lesson_ids': lessonIds,
    'visibility': visibility.name,
    'allowed_emails': visibility == CourseVisibility.selected
        ? [
            for (final e in allowedEmails)
              if (e.trim().isNotEmpty) e.trim().toLowerCase(),
          ]
        : <String>[],
  };
}
