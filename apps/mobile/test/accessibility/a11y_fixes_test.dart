import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../safety/safety_screens_test.dart' show atWhy, saveWhy;
import '../voice/voice_flow_test.dart' show atVoice, tapKey;
import 'audit_helpers.dart';
import 'prod_routes.dart';

/// T-REL-01: locks in each accessibility fix from the audit
/// (docs/audit/2026-11-19-accessibility.md), plus the safety screens, which
/// are not routes and so are not in the route sweep.
void main() {
  group('captions for every recording the coach plays (NFR-06)', () {
    testWidgets('the greeting is captioned in full', (tester) async {
      await atVoice(name: 'Robert Hall').boot(tester);
      expect(find.byKey(const Key('voice-greeting')), findsOneWidget);
      expect(
        find.text('I’m here to help, one small step at a time.'),
        findsOneWidget,
      );
    });

    testWidgets('the library shows what the samples say, per style', (
      tester,
    ) async {
      await atVoice().boot(tester);
      await tapKey(tester, 'voice-another');
      final transcript = find.byKey(const Key('voice-sample-transcript'));
      await tester.scrollUntilVisible(
        transcript,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: transcript,
          matching: find.textContaining('one small step together today'),
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Energetic'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        transcript,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: transcript,
          matching: find.textContaining('Let’s make today count'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Daily plan: each moment time is a labelled 48 dp button', (
    tester,
  ) async {
    // The times moved from Profile to Profile > Daily plan (T-DLY-03e, D-79).
    final semantics = tester.ensureSemantics();
    await openRoute(tester, const AuditRoute('/profile/daily-plan'));
    for (final kind in ['greeting', 'nudge', 'reflection']) {
      final time = find.byKey(Key('plan-time-$kind'));
      await tester.scrollUntilVisible(
        time,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(time).height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(time);
      expect(node.label, startsWith('Change the '));
      expect(node.flagsCollection.isButton, isTrue);
    }
    // Its own switch, labelled, not merged into one control with the time.
    final toggle = tester.getSemantics(
      find.descendant(
        of: find.byKey(const Key('plan-touchpoint-greeting')),
        matching: find.byType(Switch),
      ),
    );
    expect(toggle.label, contains('Morning greeting'));
    expect(
      toggle.getSemanticsData().flagsCollection.isToggled,
      isNot(Tristate.none),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  group('safety screens (FR-SAF-01/02)', () {
    final cases = {
      'crisis, India': ('IN', "I don't want to be alive anymore"),
      'crisis, US': ('US', 'I want to kill myself'),
      'emergency, region unknown': (null, 'I have crushing chest pain'),
    };
    for (final MapEntry(key: name, value: (region, text)) in cases.entries) {
      for (final dark in [false, true]) {
        testWidgets('$name ${dark ? 'dark' : 'light'}: WCAG checks', (
          tester,
        ) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await atWhy(region: region).boot(tester);
          await saveWhy(tester, text);
          expect(find.byType(SafetyInterruptScreen), findsOneWidget);
          final failures = await auditFailures(tester);
          expect(failures, isEmpty, reason: failures.join('\n'));
        });
      }
      for (final scale in [2.0, 3.1]) {
        testWidgets('$name at ${(scale * 100).round()}%: nothing overflows', (
          tester,
        ) async {
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await atWhy(region: region).boot(tester);
          await saveWhy(tester, text);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.view
            ..physicalSize = const Size(750, 1334)
            ..devicePixelRatio = 2.0;
          await tester.pumpAndSettle();
          expect(find.byType(SafetyInterruptScreen), findsOneWidget);
          // An overflow fails the test by itself; scroll to the end.
          await acrossPage(tester, (_) async {}, maxScreens: 30);
        });
      }
    }
  });
}
