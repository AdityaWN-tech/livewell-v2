import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/track/domain/metric_point.dart';

import '../home/home_screen_test.dart' show signedIn, uid;
import '../support/app_harness.dart';
import '../support/fakes.dart';
import 'track_screen_test.dart' show day, openTrack, scrollTo, text;

/// T-GOL-02 (FR-GOL-04/05, D-72): manual weight, blood pressure, glucose
/// and meals with source and time on every point; 7/30/90-day charts.

/// A profile with the eating-safe mode on (FR-SAF-04, server-set).
class _EdSafeProfiles extends FakeProfileRepository {
  @override
  Future<Profile?> get(String uid) async {
    final p = await super.get(uid);
    return p == null
        ? null
        : Profile(uid: uid, onboardingStep: p.onboardingStep, edSafeMode: true);
  }
}

Future<void> openAdd(WidgetTester tester, String kind) async {
  await scrollTo(tester, find.byKey(Key('metric-add-$kind')));
  await tester.tap(find.byKey(Key('metric-add-$kind')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('metric-entry-sheet')), findsOneWidget);
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('metric-save')));
  await tester.tap(find.byKey(const Key('metric-save')));
  await tester.pumpAndSettle();
}

Future<void> pickPeriod(WidgetTester tester, String period) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('track-period')),
    -200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('track-period')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('track-period-$period')).last);
  await tester.pumpAndSettle();
}

/// Scrolls up or down to [f].
Future<void> scrollBothWays(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await scrollTo(tester, f);
}

Future<void> chip(WidgetTester tester, String name) async {
  await scrollBothWays(tester, find.byKey(Key('track-chip-$name')));
  await tester.tap(find.byKey(Key('track-chip-$name')));
  await tester.pumpAndSettle();
}

/// Words that would interpret a value (spec 9.4: never diagnostic).
final judging = RegExp(
  r'\b(high|low|normal|elevated|danger|risk|hypertension|diabet|'
  r'healthy range|too)\b',
  caseSensitive: false,
);

void expectNoJudgement(WidgetTester tester) {
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final s = t.data ?? t.textSpan?.toPlainText() ?? '';
    // "Low" is a check-in stress answer word on the cards above.
    if (s == 'Low') continue;
    expect(judging.hasMatch(s), isFalse, reason: s);
  }
}

void main() {
  group('My measures (FR-GOL-04)', () {
    testWidgets('empty: every kind offered, nothing made up', (tester) async {
      await signedIn().boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-measures')));
      for (final k in ['weight', 'blood_pressure', 'glucose', 'meal']) {
        expect(text(tester, 'metric-$k-value'), 'Nothing yet');
        expect(find.byKey(Key('metric-$k-when')), findsNothing);
      }
    });

    testWidgets('weight: saved with its unit, source and time, shown on '
        'Track and in the chart', (tester) async {
      final h = signedIn()..profiles.regions[uid] = 'US';
      await h.boot(tester);
      await openTrack(tester);
      await openAdd(tester, 'weight');
      // Pounds in the US (NFR-11); the person can switch.
      expect(find.text('lb'), findsWidgets);
      await tester.enterText(find.byKey(const Key('metric-value')), '160.4');
      expect(text(tester, 'metric-when-text'), 'When: Today, 8:30\u202fAM');
      await save(tester);
      expect(find.text('Saved.'), findsOneWidget);

      final p = h.metrics.points.values.single;
      expect(p.kind, MetricKind.weight);
      expect(p.value, 160.4);
      expect(p.weightUnit, WeightUnit.lb);
      expect(p.source, MetricSource.manual);
      expect(p.measuredAt, h.now);

      await scrollTo(tester, find.byKey(const Key('metric-weight-value')));
      expect(text(tester, 'metric-weight-value'), '160.4 lb');
      expect(
        text(tester, 'metric-weight-when'),
        'Entered by you · Today, 8:30\u202fAM',
      );

      await chip(tester, 'weight');
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Wednesday: 160.4 lb. Selected.'),
        findsOneWidget,
      );
      expect(text(tester, 'track-chart-source'), 'Entered by you');
      handle.dispose();
    });

    testWidgets('kilograms: typos outside the limits are caught kindly', (
      tester,
    ) async {
      final h = signedIn()..profiles.regions[uid] = 'IN';
      await h.boot(tester);
      await openTrack(tester);
      await openAdd(tester, 'weight');
      await tester.enterText(find.byKey(const Key('metric-value')), '725');
      await save(tester);
      expect(
        text(tester, 'metric-error'),
        'Please enter a weight between 20 and 300 kg.',
      );
      expect(h.metrics.points, isEmpty);
      await tester.enterText(find.byKey(const Key('metric-value')), '72,5');
      await save(tester);
      expect(h.metrics.points.values.single.value, 72.5);
      expect(h.metrics.points.values.single.weightUnit, WeightUnit.kg);
    });

    testWidgets('blood pressure: recorded as it is, never judged', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openTrack(tester);
      await openAdd(tester, 'blood_pressure');
      // Top lower than bottom: a typo.
      await tester.enterText(find.byKey(const Key('metric-systolic')), '80');
      await tester.enterText(find.byKey(const Key('metric-diastolic')), '120');
      await save(tester);
      expect(find.byKey(const Key('metric-error')), findsOneWidget);
      expect(h.metrics.points, isEmpty);
      // A very high reading inside the limits: saved without comment.
      await tester.enterText(find.byKey(const Key('metric-systolic')), '210');
      await tester.enterText(find.byKey(const Key('metric-diastolic')), '125');
      expect(find.textContaining('doesn\'t comment on it'), findsOneWidget);
      expectNoJudgement(tester);
      await save(tester);
      final p = h.metrics.points.values.single;
      expect((p.systolic, p.diastolic), (210, 125));
      await scrollTo(
        tester,
        find.byKey(const Key('metric-blood_pressure-value')),
      );
      expect(text(tester, 'metric-blood_pressure-value'), '210/125 mmHg');
      expectNoJudgement(tester);
      await chip(tester, 'bloodPressure');
      expect(find.text('210/125 mmHg'), findsWidgets);
      expectNoJudgement(tester);
    });

    testWidgets('glucose: whole mg/dL; a low reading is just recorded', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openTrack(tester);
      await openAdd(tester, 'glucose');
      await tester.enterText(find.byKey(const Key('metric-value')), '650');
      await save(tester);
      expect(
        text(tester, 'metric-error'),
        'Please enter a whole number between 20 and 600.',
      );
      await tester.enterText(find.byKey(const Key('metric-value')), '45');
      await save(tester);
      expect(h.metrics.points.values.single.value, 45);
      await scrollTo(tester, find.byKey(const Key('metric-glucose-value')));
      expect(text(tester, 'metric-glucose-value'), '45 mg/dL');
      expectNoJudgement(tester);
    });

    testWidgets('meals: which meal only, no free text', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openTrack(tester);
      await openAdd(tester, 'meal');
      expect(
        find.descendant(
          of: find.byKey(const Key('metric-entry-sheet')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      await save(tester);
      expect(text(tester, 'metric-error'), 'Which meal?');
      await tester.tap(find.byKey(const Key('metric-meal-lunch')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(h.metrics.points.values.single.meal, MealKind.lunch);
      await scrollTo(tester, find.byKey(const Key('metric-meal-value')));
      expect(text(tester, 'metric-meal-value'), 'Lunch');
    });

    testWidgets('every entry lists its source and time; a wrong one can be '
        'deleted', (tester) async {
      final h = signedIn();
      h.metrics.points['a'] = MetricPoint.glucose(
        id: 'a',
        mgDl: 101,
        measuredAt: DateTime(2026, 10, 12, 7, 15),
      );
      h.metrics.points['b'] = MetricPoint.glucose(
        id: 'b',
        mgDl: 96,
        measuredAt: DateTime(2026, 10, 13, 19, 40),
        source: MetricSource.health,
      );
      await h.boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('metric-row-glucose')));
      await tester.tap(find.byKey(const Key('metric-row-glucose')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('metric-history-sheet')), findsOneWidget);
      Finder inSheet(String s) => find.descendant(
        of: find.byKey(const Key('metric-history-sheet')),
        matching: find.text(s),
      );
      expect(inSheet('Entered by you · Oct 12, 7:15\u202fAM'), findsOneWidget);
      expect(
        inSheet('From Health Connect · Yesterday, 7:40\u202fPM'),
        findsOneWidget,
      );
      // Newest first.
      expect(
        tester.getTopLeft(inSheet('96 mg/dL')).dy,
        lessThan(tester.getTopLeft(inSheet('101 mg/dL')).dy),
      );
      await tester.tap(find.byKey(const Key('metric-delete-a')));
      await tester.pumpAndSettle();
      expect(h.metrics.points.keys, ['b']);
      expect(find.text('Deleted.'), findsOneWidget);
    });

    testWidgets('eating-safe mode: no weight or meals (FR-SAF-04)', (
      tester,
    ) async {
      final h = Harness(
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
        profiles: _EdSafeProfiles(),
        namePrompt: FakeNamePromptStore(wasAsked: true),
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      await h.boot(tester);
      await openTrack(tester);
      await scrollTo(tester, find.byKey(const Key('track-measures')));
      expect(find.byKey(const Key('metric-add-weight')), findsNothing);
      expect(find.byKey(const Key('metric-add-meal')), findsNothing);
      expect(find.byKey(const Key('metric-add-glucose')), findsOneWidget);
      await chip(tester, 'glucose');
      expect(find.byKey(const Key('track-chip-weight')), findsNothing);
      expect(find.byKey(const Key('track-chip-meals')), findsNothing);
      expect(find.byKey(const Key('track-chip-glucose')), findsOneWidget);
    });
  });

  group('7/30/90-day charts (FR-GOL-05)', () {
    testWidgets('This Month and 90 days show weeks, labelled, with averages', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      for (final (id, day, kg) in [
        ('a', DateTime(2026, 10, 5, 8), 80.0),
        ('b', DateTime(2026, 10, 7, 8), 79.0),
        ('c', DateTime(2026, 10, 13, 8), 78.0),
        ('d', DateTime(2026, 9, 20, 8), 82.0),
      ]) {
        h.metrics.points[id] = MetricPoint.weight(
          id: id,
          kgOrLb: kg,
          unit: WeightUnit.kg,
          measuredAt: day,
        );
      }
      await h.boot(tester);
      await openTrack(tester);
      await chip(tester, 'weight');
      // This Week: by day.
      expect(
        find.bySemanticsLabel('Tuesday: 78 kg. Selected.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Monday: nothing logged'), findsOneWidget);

      await pickPeriod(tester, 'month');
      await scrollTo(tester, find.byKey(const Key('track-chart-period')));
      expect(text(tester, 'track-chart-period'), 'This month, week by week');
      // Oct 2026: 5 weeks, the current one selected.
      expect(find.byKey(const Key('track-bar-4')), findsOneWidget);
      expect(find.byKey(const Key('track-bar-5')), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Week of October 12: 78 kg on average. Selected.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Week of October 5: 79.5 kg on average'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Week of October 1: nothing logged'),
        findsOneWidget,
      );
      // Weeks can be tapped.
      await tester.tap(find.byKey(const Key('track-bar-1')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Week of October 5: 79.5 kg on average. Selected.',
        ),
        findsOneWidget,
      );

      await pickPeriod(tester, 'quarter');
      await scrollTo(tester, find.byKey(const Key('track-chart-period')));
      expect(text(tester, 'track-chart-period'), 'Last 90 days, week by week');
      expect(
        find.bySemanticsLabel('Week of September 14: 82 kg on average'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('track-bar-12')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mood over 90 days uses the answer words', (tester) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      h.checkIns.days['2026-08-03'] = day('2026-08-03', 2);
      h.checkIns.days['2026-08-04'] = day('2026-08-04', 4);
      await h.boot(tester);
      await openTrack(tester);
      await pickPeriod(tester, 'quarter');
      await scrollTo(tester, find.byKey(const Key('track-chart-period')));
      expect(
        find.bySemanticsLabel('Week of August 3: Okay on average. Selected.'),
        findsOneWidget,
      );
      expect(text(tester, 'track-chart-source'), 'From your check-ins');
      handle.dispose();
    });

    testWidgets('steps for 30 days come from Health, with when they were '
        'read', (tester) async {
      final handle = tester.ensureSemantics();
      final h = signedIn();
      await h.consents.record(ConsentType.healthData, granted: true);
      h.health.days = {'2026-10-05': 5000, '2026-10-06': 7000};
      await h.boot(tester);
      await openTrack(tester);
      await chip(tester, 'steps');
      expect(
        text(tester, 'track-chart-source'),
        'From Health Connect, read 8:30\u202fAM',
      );
      await pickPeriod(tester, 'month');
      await scrollTo(tester, find.byKey(const Key('track-chart-period')));
      expect(
        find.bySemanticsLabel('Week of October 5: 6,000 on average'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
