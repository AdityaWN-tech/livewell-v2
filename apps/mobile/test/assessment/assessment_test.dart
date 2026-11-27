// The 10-minute check (ASM-01, D-114).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/assessment/domain/assessment.dart';
import 'package:livewell/features/assessment/presentation/assessment_screen.dart';

import '../home/home_screen_test.dart' show signedIn;

const _qs = [
  AssessmentQuestion(
    id: 'q1',
    driverId: 'driver_2',
    text: 'How rested do you feel?',
    order: 1,
  ),
  AssessmentQuestion(
    id: 'q2',
    driverId: 'driver_1',
    text: 'Do you move most days?',
  ),
  AssessmentQuestion(
    id: 'q3',
    driverId: 'driver_2',
    text: 'Do you sleep at a steady time?',
    order: 2,
  ),
];

Future<void> _openPlan(WidgetTester tester) async {
  await tester.tap(find.text('Plan').last);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('scoring (provisional)', () {
    test('mean of (answer - 1) / 4 per driver; asked driver by driver', () {
      expect(askingOrder(_qs).map((q) => q.id), ['q2', 'q1', 'q3']);
      final s = driverScores(_qs, {'q1': 5, 'q2': 1, 'q3': 3});
      expect(s['driver_1'], 0);
      expect(s['driver_2'], closeTo(0.75, 1e-9));
      expect(s.containsKey('driver_3'), isFalse);
      expect(bankVersion(_qs), 'q2@1,q1@1,q3@1');
    });
    test('out-of-range answers are ignored', () {
      expect(driverScores(_qs, {'q1': 9, 'q2': 0}), isEmpty);
    });
  });

  testWidgets('off in prod: the map keeps its plain line', (tester) async {
    final h = signedIn();
    h.assessment.questions = _qs;
    await h.boot(tester);
    await _openPlan(tester);
    await _scrollTo(tester, const Key('plan-map-empty'));
    expect(find.byKey(const Key('plan-start-check')), findsNothing);
  });

  testWidgets('on: start from the map, answer every question, the map fills', (
    tester,
  ) async {
    final h = signedIn(flavor: Flavor.dev);
    h.assessment.questions = _qs;
    await h.boot(tester);
    await _openPlan(tester);
    await _scrollTo(tester, const Key('plan-start-check'));
    await tester.tap(find.byKey(const Key('plan-start-check')));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentScreen), findsOneWidget);
    expect(find.textContaining('3 short questions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('check-start')));
    await tester.pumpAndSettle();
    expect(find.text('Do you move most days?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('check-answer-5')));
    await tester.pumpAndSettle();
    // Back works, and keeps going forward.
    await tester.tap(find.byKey(const Key('check-back')));
    await tester.pumpAndSettle();
    expect(find.text('Do you move most days?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('check-answer-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-answer-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-answer-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('check-done')), findsOneWidget);
    expect(h.assessment.saved.single, {'q2': 5, 'q1': 3, 'q3': 3});
    expect(h.assessment.latest, {'driver_1': 1.0, 'driver_2': 0.5});

    await tester.tap(find.byKey(const Key('check-see-map')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('plan-map'));
    expect(find.byKey(const Key('plan-start-check')), findsNothing);
  });

  testWidgets('approved driver names replace the placeholders', (tester) async {
    final h = signedIn(flags: const FeatureFlags(assessment: true));
    h.assessment.labels = const [
      'Move',
      'Sleep',
      'Food',
      'Calm',
      'Energy',
      'Routine',
      'Connect',
      'Purpose',
    ];
    await h.boot(tester);
    await _openPlan(tester);
    await _scrollTo(tester, const Key('plan-map'));
    expect(find.text('Driver 1'), findsNothing);
  });
}
