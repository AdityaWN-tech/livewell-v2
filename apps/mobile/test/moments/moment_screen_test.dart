import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/dev/presentation/moments_gallery.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/presentation/moment_screen.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import '../support/app_harness.dart';

/// T-DLY-03b: the full-screen Avatar Moment player.

/// Opens [m] from Home (dev preview data: Priya, the sample walk).
Future<void> open(WidgetTester tester, Moment m) async {
  GoRouter.of(tester.element(find.byType(HomeScreen)))
      .push(MomentScreen.pathFor(m));
  // Not pumpAndSettle: while the coach speaks, the mouth keeps moving.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(MomentScreen), findsOneWidget);
}

/// The words shown so far in the bubble.
String shown(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('moment-text')));
  final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
  return spans.first.text!;
}

AvatarExpression face(WidgetTester tester) => tester
    .widget<AvatarView>(find.byKey(const Key('moment-avatar')))
    .expression;

/// Lets the coach finish speaking.
Future<void> finish(WidgetTester tester, Harness h) async {
  h.speaker.finish();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('speaks the morning message: its message_id, the voice '
      'speed, the AI voice label, words appear as they are said', (
    tester,
  ) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.morning);
    final (msg, speed) = h.speaker.spoken.single;
    expect(msg.moment, Moment.morning);
    expect(msg.messageId, startsWith('morning.'));
    expect(speed, 1.0);
    expect(find.byKey(const Key('ai-voice-label')), findsOneWidget);
    // Nothing shown yet; then the words as they are spoken.
    expect(shown(tester), isEmpty);
    h.speaker.word(12);
    await tester.pump();
    expect(shown(tester), msg.text.substring(0, 12));
    await finish(tester, h);
    expect(shown(tester), msg.text);
    expect(msg.text, contains('Priya'));
    expect(find.byKey(const Key('moment-play')), findsOneWidget);
  });

  testWidgets('the mouth moves while speaking; rests after', (tester) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.stepReminder);
    final faces = <AvatarExpression>{};
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 160));
      faces.add(face(tester));
    }
    expect(faces, contains(AvatarExpression.talking));
    await finish(tester, h);
    // Encouraging uses the happy face until the art kit has its own.
    expect(face(tester), AvatarExpression.happy);
  });

  for (final (m, expected) in [
    (Moment.morning, AvatarExpression.waving),
    (Moment.stepDone, AvatarExpression.celebrating),
    (Moment.evening, AvatarExpression.listening),
    (Moment.gentle, AvatarExpression.calm),
  ]) {
    testWidgets('the ${m.file} face: ${expected.name}', (tester) async {
      final h = await bootPreview(tester);
      await open(tester, m);
      await finish(tester, h);
      expect(face(tester), expected);
    });
  }

  testWidgets('pause, then play again from the start', (tester) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.evening);
    await tester.tap(find.byKey(const Key('moment-pause')));
    await tester.pumpAndSettle();
    expect(h.speaker.pauses, 1);
    await tester.tap(find.byKey(const Key('moment-play')));
    await tester.pump();
    await tester.pump();
    expect(h.speaker.spoken, hasLength(2));
    await finish(tester, h);
  });

  testWidgets('mute: the voice stops, the whole text shows, no AI label', (
    tester,
  ) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.morning);
    await tester.tap(find.byKey(const Key('moment-mute')));
    await tester.pumpAndSettle();
    expect(h.speaker.stops, greaterThanOrEqualTo(1));
    expect(shown(tester), h.speaker.spoken.single.$1.text);
    expect(find.byKey(const Key('ai-voice-label')), findsNothing);
    expect(find.byKey(const Key('moment-play')), findsNothing);
    // Voice back on: it speaks again.
    await tester.tap(find.byKey(const Key('moment-mute')));
    await tester.pump();
    await tester.pump();
    expect(h.speaker.spoken, hasLength(2));
    await finish(tester, h);
  });

  testWidgets('skip shows the whole message at once', (tester) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.stepDone);
    await tester.tap(find.byKey(const Key('moment-skip')));
    await tester.pumpAndSettle();
    expect(shown(tester), h.speaker.spoken.single.$1.text);
  });

  testWidgets('reduced motion: still avatar, whole text, voice still on', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final h = await bootPreview(tester);
    await open(tester, Moment.morning);
    expect(shown(tester), h.speaker.spoken.single.$1.text);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 160));
      expect(face(tester), AvatarExpression.waving);
    }
    await finish(tester, h);
  });

  testWidgets('the voice can\'t start: the message as text (FR-AVT-05)', (
    tester,
  ) async {
    final h = Harness(flavor: Flavor.dev);
    h.speaker.works = false;
    await h.boot(tester);
    await tester.scrollUntilVisible(
      find.text('Preview the app (dev build only)'),
      200,
    );
    await tester.tap(find.text('Preview the app (dev build only)'));
    await tester.pumpAndSettle();
    await open(tester, Moment.evening);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment-text-only')), findsOneWidget);
    expect(shown(tester), contains('how did today go'));
    expect(find.byKey(const Key('ai-voice-label')), findsNothing);
  });

  testWidgets('screen readers get the whole message from the start', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await bootPreview(tester);
    await open(tester, Moment.evening);
    final text = h.speaker.spoken.single.$1.text;
    expect(find.bySemanticsLabel(text), findsOneWidget);
    await finish(tester, h);
    handle.dispose();
  });

  testWidgets('the buttons return the chosen action', (tester) async {
    final h = await bootPreview(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(MomentsGallery.path);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dev-moment-morning')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await finish(tester, h);
    expect(find.byKey(const Key('moment-action-checkIn')), findsOneWidget);
    expect(find.byKey(const Key('moment-action-makeSmaller')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('moment-action-startStep')),
    );
    await tester.tap(find.byKey(const Key('moment-action-startStep')));
    await tester.pumpAndSettle();
    expect(find.text('Chose: startStep'), findsOneWidget);
  });

  testWidgets('closing stops the voice', (tester) async {
    final h = await bootPreview(tester);
    await open(tester, Moment.morning);
    await tester.tap(find.byKey(const Key('moment-close')));
    await tester.pumpAndSettle();
    expect(find.byType(MomentScreen), findsNothing);
    expect(h.speaker.stops, greaterThanOrEqualTo(1));
  });

  testWidgets('prod: scripts not approved yet, so nothing is said', (
    tester,
  ) async {
    final h = signedIn();
    await h.boot(tester);
    await open(tester, Moment.morning);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moment-none')), findsOneWidget);
    expect(h.speaker.spoken, isEmpty);
  });

  testWidgets('an unknown moment goes Home', (tester) async {
    await bootPreview(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push('/moment/nonsense');
    await tester.pumpAndSettle();
    expect(find.byType(MomentScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('iPhone SE, text $scale: no overflow, buttons reachable', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      tester.view
        ..physicalSize = const Size(750, 1334)
        ..devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await open(tester, Moment.morning);
      await finish(tester, h);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('moment-action-makeSmaller')),
        200,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
