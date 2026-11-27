// Courses written by staff Admins, in the app's Learn tab (D-113).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/learn/domain/course.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/presentation/course_screen.dart';
import 'package:livewell/features/learn/presentation/lesson_reader_screen.dart';

import '../home/home_screen_test.dart' show signedIn;
import 'learn_screen_test.dart' show openLearn;

Lesson _lesson(String id, String title) => Lesson(
  id: id,
  category: 'Sleep',
  title: title,
  cards: const ['Dim the lights an hour before bed.'],
);

const _course = Course(
  id: 'c1',
  title: 'Better sleep in 7 days',
  category: 'Sleep',
  summary: 'Small evening changes.',
  lessonIds: ['l1', 'l2', 'gone'],
);

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a course shows on Learn with its progress, then its lessons '
      'in order; Start opens the first', (tester) async {
    final h = signedIn();
    h.learn.lessons = [
      _lesson('l1', 'Lights low'),
      _lesson('l2', 'Screens off'),
    ];
    h.learn.courses = const [_course];
    await h.boot(tester);
    await openLearn(tester);

    await _scrollTo(tester, const Key('course-c1'));
    expect(find.text('Better sleep in 7 days'), findsOneWidget);
    // A lesson that isn't available ('gone') doesn't count.
    expect(find.text('0 of 2 done'), findsOneWidget);

    await tester.tap(find.byKey(const Key('course-c1')));
    await tester.pumpAndSettle();
    expect(find.byType(CourseScreen), findsOneWidget);
    expect(find.byKey(const Key('course-lesson-l1')), findsOneWidget);
    expect(find.byKey(const Key('course-lesson-l2')), findsOneWidget);
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('course-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(LessonReaderScreen), findsOneWidget);
    expect(find.text('Lights low'), findsWidgets);
  });

  testWidgets('no courses: no Courses section', (tester) async {
    final h = signedIn();
    h.learn.lessons = [_lesson('l1', 'Lights low')];
    await h.boot(tester);
    await openLearn(tester);
    expect(find.text('Courses'), findsNothing);
  });
}
