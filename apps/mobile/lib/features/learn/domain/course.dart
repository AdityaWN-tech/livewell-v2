/// A course written by staff Admins (D-113): approved lessons in order.
/// The app sees only approved courses for everyone, or ones that list the
/// person's sign-in email (the Firestore rules decide).
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.category,
    required this.lessonIds,
    this.summary,
  });

  final String id;
  final String title;
  final String category;
  final String? summary;

  /// Lessons in reading order.
  final List<String> lessonIds;
}
