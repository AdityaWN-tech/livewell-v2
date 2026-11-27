import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/illustrated.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/learn_data.dart';
import '../domain/course.dart';
import '../domain/lesson.dart';

/// The course's lessons and progress, from the learn data.
(List<Lesson>, Map<String, ContentProgress>) _courseLessons(
  WidgetRef ref,
  Course c,
) {
  final byId = {
    for (final l in ref.watch(lessonsProvider).value ?? const <Lesson>[])
      l.id: l,
  };
  final progress = ref.watch(contentProgressProvider).value ?? const {};
  return ([for (final id in c.lessonIds) ?byId[id]], progress);
}

/// A course on Learn (D-113): its title and how far the person is.
class CourseCard extends ConsumerWidget {
  const CourseCard(this.course, {super.key});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final (lessons, progress) = _courseLessons(ref, course);
    final (done, total) = courseProgress(course, {
      for (final x in lessons) x.id: x,
    }, progress);
    return LwPastelCard(
      key: Key('course-${course.id}'),
      tint: p.lavender,
      onTap: () => context.push(CourseScreen.pathFor(course.id)),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: p.onTint, size: LwSize.iconMd),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: t.titleSmall?.copyWith(color: p.onTint),
                ),
                Text(
                  l.learnCourseProgress(done, total),
                  style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                ),
                const SizedBox(height: LwSpacing.xs),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  semanticsLabel: l.learnCourseProgress(done, total),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.onTint),
        ],
      ),
    );
  }
}

/// One course: its lessons in order, with ticks, and Continue.
class CourseScreen extends ConsumerWidget {
  const CourseScreen({super.key, required this.id});
  final String id;

  static String pathFor(String id) => '/learn/course/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final course = ref.watch(courseByIdProvider(id));
    if (course == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.learnCoursesTitle)),
        body: Center(child: Text(l.learnCourseEmpty)),
      );
    }
    final (lessons, progress) = _courseLessons(ref, course);
    bool done(Lesson x) => progress[x.id]?.completed ?? false;
    final next = lessons.where((x) => !done(x)).firstOrNull;
    final started = lessons.any(done);
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          if (course.summary case final s?) ...[
            Text(s, style: t.bodyLarge),
            const SizedBox(height: LwSpacing.md),
          ],
          if (lessons.isEmpty)
            Text(l.learnCourseEmpty)
          else ...[
            Text(
              l.learnCourseProgress(lessons.where(done).length, lessons.length),
              style: t.titleSmall,
            ),
            const SizedBox(height: LwSpacing.sm),
            for (final (i, x) in lessons.indexed)
              ListTile(
                key: Key('course-lesson-${x.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  done(x) ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done(x) ? p.primary : p.textSecondary,
                ),
                title: Text(x.title),
                subtitle: Text(l.learnCourseLessonNumber(i + 1)),
                onTap: () => context.push('/learn/item/${x.id}'),
              ),
            const SizedBox(height: LwSpacing.md),
            if (next == null)
              Text(
                l.learnCourseDone,
                key: const Key('course-done'),
                style: t.titleSmall,
              )
            else
              FilledButton(
                key: const Key('course-continue'),
                onPressed: () => context.push('/learn/item/${next.id}'),
                child: Text(
                  started ? l.learnCourseContinue : l.learnCourseStart,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
