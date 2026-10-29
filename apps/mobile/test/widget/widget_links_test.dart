import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/presentation/celebration.dart';
import 'package:livewell/features/track/presentation/track_screen.dart';
import 'package:livewell/features/widget/data/widget_inbox.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart';

import '../home/home_screen_test.dart' show bootPreview, today;
import 'widget_snapshot_test.dart' show builder, day;

/// T-AVT-08g-b: the app side of the iOS widget: its links, Done tapped on
/// the widget, and what the widget shows right after Done.

ProviderContainer scope(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

/// The app goes to the background and comes back.
void backToTheApp(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  test('the widget links', () {
    WidgetLink? p(String s) => parseWidgetLink(Uri.parse(s));
    expect(p('livewell://checkin?homeWidget=1'), WidgetLink.checkIn);
    expect(p('livewell://step'), WidgetLink.step);
    expect(p('livewell://step?smaller=1'), WidgetLink.makeSmaller);
    expect(p('livewell://step?done=1&homeWidget=1'), WidgetLink.done);
    expect(p('livewell://reflection'), WidgetLink.reflect);
    expect(p('livewell://home'), WidgetLink.home);
    expect(p('livewell://portal'), isNull);
    expect(p('https://example.com/step'), isNull);
    expect(parseWidgetLink(null), isNull);
    // Every action the widget offers has a link the app understands.
    for (final a in WidgetActionId.values) {
      expect(parseWidgetLink(Uri.parse(a.link)), isNotNull, reason: a.id);
    }
  });

  test('after Done on the widget: the celebration, the streak counted', () {
    final s = builder.build(day(13, minute: 30, checkedIn: true));
    final after = s.afterDone!;
    expect(after.slot, WidgetSlot.done);
    expect(after.expression, 'celebrating');
    expect(after.headline, 'Day 10!');
    // Nothing to celebrate twice, or without a step.
    expect(
      builder.build(day(15, checkedIn: true, done: true)).afterDone,
      isNull,
    );
    expect(builder.build(day(9, plan: false)).afterDone, isNull);
    // Calm after a safety response, even then.
    expect(
      builder.build(day(14, checkedIn: true, hold: true)).afterDone!.expression,
      'calm',
    );
    expect(s.routineLabels, {
      'morning': 'Morning',
      'step': 'Step',
      'evening': 'Evening',
    });
  });

  group('the app follows the widget', () {
    testWidgets('Done tapped on the widget today is applied once, quietly', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      expect(scope(tester).read(stepProgressProvider).done, isFalse);
      h.widgetInbox.done = today;
      // Coming back to the app.
      backToTheApp(tester);
      await tester.pumpAndSettle();
      expect(scope(tester).read(stepProgressProvider).done, isTrue);
      expect(find.byKey(const Key('celebration')), findsNothing);
    });

    testWidgets("a Done from an earlier day isn't today's, but is saved for "
        'that day (D-60)', (tester) async {
      final h = await bootPreview(tester);
      h.widgetInbox.done = '2026-10-13';
      backToTheApp(tester);
      await tester.pumpAndSettle();
      expect(scope(tester).read(stepProgressProvider).done, isFalse);
      expect(h.goals.logs.keys, contains('2026-10-13_daily_step'));
    });

    testWidgets('Check in opens the check-in', (tester) async {
      final h = await bootPreview(tester);
      h.widgetInbox.tap(WidgetLink.checkIn);
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsOneWidget);
    });

    testWidgets('Done (iOS 16) celebrates once', (tester) async {
      final h = await bootPreview(tester);
      h.widgetInbox.tap(WidgetLink.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Celebration), findsOneWidget);
      expect(scope(tester).read(stepProgressProvider).done, isTrue);
      await tester.tap(find.byKey(const Key('celebration')));
      await tester.pumpAndSettle();
      h.widgetInbox.tap(WidgetLink.done);
      await tester.pumpAndSettle();
      expect(find.byType(Celebration), findsNothing);
    });

    testWidgets('Make it smaller, and Reflect goes to Track', (tester) async {
      final h = await bootPreview(tester);
      h.widgetInbox.tap(WidgetLink.makeSmaller);
      await tester.pumpAndSettle();
      expect(scope(tester).read(stepProgressProvider).smaller, isTrue);
      h.widgetInbox.tap(WidgetLink.reflect);
      await tester.pumpAndSettle();
      expect(find.byType(TrackScreen), findsOneWidget);
    });
  });
}
