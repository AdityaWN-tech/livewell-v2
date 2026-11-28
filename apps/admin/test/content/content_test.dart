// Lessons and courses written by Admins (D-113/D-114).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/auth/staff.dart';
import 'package:livewell_admin/features/content/domain/content.dart';
import 'package:livewell_admin/features/content/domain/content_check.dart';
import 'package:livewell_admin/features/staff/domain/staff_access.dart';

import '../support/harness.dart';

const _cardText = 'Dim the lights an hour before bed.';

LessonDoc _lesson(String id, ReviewState s, {String author = 'priya'}) =>
    LessonDoc(
      id: id,
      title: 'Sleep starts in the evening',
      category: 'Sleep',
      cards: const [_cardText],
      state: s,
      authorUid: author,
    );

Future<void> _open(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  group('content check (no medicine advice, cures or fear)', () {
    test('flags what must not go out', () {
      expect(
        checkContent('Stop taking your medication if you feel better.'),
        isNotEmpty,
      );
      expect(checkContent('Take 500 mg each morning.'), isNotEmpty);
      expect(checkContent('This plan will cure your diabetes.'), isNotEmpty);
      expect(checkContent('Results guaranteed in a week.'), isNotEmpty);
      expect(checkContent('Act now or else.'), isNotEmpty);
    });
    test('lets kind, plain advice through', () {
      expect(
        checkContent(
          'A short walk after lunch helps. Talk to your doctor about your medicines.',
        ),
        isEmpty,
      );
      expect(checkContent(_cardText), isEmpty);
    });
  });

  testWidgets('an approved Admin starts at Content and writes a lesson', (
    tester,
  ) async {
    final content = FakeContentRepository();
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
    );
    expect(find.byKey(const Key('tab-lessons')), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-lesson')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lesson-title')),
      'Sleep starts in the evening',
    );
    await tester.enterText(find.byKey(const Key('lesson-category')), 'Sleep');
    await tester.enterText(find.byKey(const Key('lesson-cards')), _cardText);
    await tester.pumpAndSettle();
    await _open(tester, const Key('content-submit'));
    expect(content.log, ['create lesson l0', 'submit l0']);
    expect(content.lessonsNow.single.state, ReviewState.pending);
    expect(
      find.text('Waiting for a clinical reviewer (2-person rule).'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('content-approve')), findsNothing);
  });

  testWidgets('the check blocks submitting a cure promise', (tester) async {
    final content = FakeContentRepository();
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
      location: '/content/lessons/new',
    );
    await tester.enterText(
      find.byKey(const Key('lesson-title')),
      'Reverse your diabetes',
    );
    await tester.enterText(find.byKey(const Key('lesson-category')), 'Food');
    await tester.enterText(
      find.byKey(const Key('lesson-cards')),
      'Eat greens.',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('content-issues')), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('content-submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('an Admin without the reviewer role cannot approve (D-118)', (
    tester,
  ) async {
    final content = FakeContentRepository(
      lessons: [_lesson('l1', ReviewState.pending, author: 'priya')],
    );
    await pumpAdmin(
      tester,
      session: person('ravi'),
      staff: FakeStaffAccessRepository(
        access: StaffAccess.active,
        myRoles: const {StaffRole.contentEditor, StaffRole.safetyReviewer},
      ),
      content: content,
    );
    await tester.tap(find.byKey(const Key('tab-review')));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Waiting for a clinical reviewer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-lesson-l1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('content-approve')), findsNothing);
    expect(find.byKey(const Key('content-reject')), findsNothing);
    expect(find.byKey(const Key('content-not-reviewer')), findsOneWidget);
    expect(content.log, isEmpty);
  });

  testWidgets('a clinical reviewer (not the author) approves; it goes live', (
    tester,
  ) async {
    final content = FakeContentRepository(
      lessons: [_lesson('l1', ReviewState.pending, author: 'priya')],
    );
    await pumpAdmin(
      tester,
      session: person('ravi'),
      staff: FakeStaffAccessRepository(
        access: StaffAccess.active,
        myRoles: const {StaffRole.clinicalReviewer},
      ),
      content: content,
    );
    await tester.tap(find.byKey(const Key('tab-review')));
    await tester.pumpAndSettle();
    expect(find.text('Review (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-lesson-l1')));
    await tester.pumpAndSettle();
    await _open(tester, const Key('content-approve'));
    expect(content.log, ['approve l1 by ravi']);
    expect(content.lessonsNow.single.state, ReviewState.approved);
  });

  testWidgets('a live lesson: edit makes a new version', (tester) async {
    final content = FakeContentRepository(
      lessons: [_lesson('l1', ReviewState.approved)],
    );
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
      location: '/content/lessons/l1',
    );
    await _open(tester, const Key('content-reopen'));
    expect(content.log, ['reopen l1 v2']);
    expect(content.lessonsNow.single.state, ReviewState.draft);
  });

  testWidgets('a course: chosen live lessons, for chosen people', (
    tester,
  ) async {
    final content = FakeContentRepository(
      lessons: [
        _lesson('l1', ReviewState.approved),
        _lesson('l2', ReviewState.draft),
      ],
    );
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
      location: '/content/courses/new',
    );
    // Only live lessons can go in a course.
    expect(find.byKey(const Key('course-pick-l2')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('course-title')),
      'Better sleep in 7 days',
    );
    await tester.enterText(find.byKey(const Key('course-category')), 'Sleep');
    await tester.tap(find.byKey(const Key('course-pick-l1')));
    await tester.pumpAndSettle();
    await _open(tester, const Key('course-selected'));
    await tester.enterText(
      find.byKey(const Key('course-emails')),
      'priya@gmail.com',
    );
    await tester.pumpAndSettle();
    await _open(tester, const Key('content-save'));
    expect(content.log, ['create course c0 l1 selected']);
    expect(
      content.coursesNow.single.allowedEmails,
      contains('priya@gmail.com'),
    );
  });
}
