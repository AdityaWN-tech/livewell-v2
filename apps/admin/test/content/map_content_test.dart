// Driver names and the 10-minute check's questions (D-114).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/features/content/domain/content.dart';
import 'package:livewell_admin/features/staff/domain/staff_access.dart';

import '../support/harness.dart';

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('change the driver names: a draft, then submit', (tester) async {
    final content = FakeContentRepository();
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
      location: '/content/drivers/new',
    );
    // Starts from the live (placeholder) names.
    expect(find.text('Driver 1'), findsWidgets);
    await tester.enterText(find.byKey(const Key('driver-name-1')), 'Move');
    await tester.pumpAndSettle();
    await _tap(tester, const Key('content-submit'));
    expect(content.log, ['save drivers s0 Move', 'submit s0']);
    expect(content.sets.single.state, ReviewState.pending);
  });

  testWidgets(
    'a question: counts towards a driver; the check blocks dose talk',
    (tester) async {
      final content = FakeContentRepository();
      await pumpAdmin(
        tester,
        session: person('priya'),
        staff: FakeStaffAccessRepository(access: StaffAccess.active),
        content: content,
        location: '/content/questions/new',
      );
      await tester.enterText(
        find.byKey(const Key('question-text')),
        'Did you reduce your insulin dose?',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-issues')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('question-text')),
        'How rested do you feel when you wake up?',
      );
      await tester.pumpAndSettle();
      await _tap(tester, const Key('content-save'));
      expect(content.log, ['save question q0 driver_1']);
    },
  );

  testWidgets('the Map tab lists questions under live driver names', (
    tester,
  ) async {
    final content = FakeContentRepository()
      ..sets.add(
        const DriverSetDoc(
          id: 's1',
          labels: [
            'Move',
            'Sleep',
            'Food',
            'Calm',
            'Energy',
            'Routine',
            'Connect',
            'Purpose',
          ],
          state: ReviewState.approved,
        ),
      )
      ..questionsList.add(
        const QuestionDoc(
          id: 'q1',
          driverId: 'driver_2',
          text: 'How rested do you feel?',
          state: ReviewState.approved,
        ),
      );
    await pumpAdmin(
      tester,
      session: person('priya'),
      staff: FakeStaffAccessRepository(access: StaffAccess.active),
      content: content,
    );
    await tester.tap(find.byKey(const Key('tab-map')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1. Move'), findsOneWidget);
    expect(find.text('How rested do you feel?'), findsOneWidget);
    expect(find.text('Sleep · order 0'), findsOneWidget);
  });
}
