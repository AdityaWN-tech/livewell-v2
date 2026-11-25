import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/moments/application/moment_playback.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';

import '../starter_plan/daily_plan_screen_test.dart' show signedIn;
import '../support/app_harness.dart';
import 'moment_screen_test.dart' show finish, open, shown;

/// T-DLY-03e: the Avatar Moment player follows Profile > Daily plan.

Future<Harness> boot(WidgetTester tester, MomentPlayback p) async {
  final h = signedIn(
    flavor: Flavor.dev,
    settings: {ProfileSettings.momentPlayback: p.toMap()},
  );
  await h.boot(tester);
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  return h;
}

void main() {
  testWidgets('"Show text only": nothing is spoken on open; the whole '
      'message shows, and play speaks it', (tester) async {
    final h = await boot(tester, const MomentPlayback(autoSpeak: false));
    await open(tester, Moment.evening);
    await tester.pumpAndSettle();
    expect(h.speaker.spoken, isEmpty);
    final text = tester.widget<Text>(find.byKey(const Key('moment-text')));
    final full = (text.textSpan! as TextSpan).toPlainText();
    expect(shown(tester), full);
    expect(full, isNotEmpty);
    await tester.tap(find.byKey(const Key('moment-play')));
    await tester.pump();
    await tester.pump();
    expect(h.speaker.spoken.single.$1.moment, Moment.evening);
    await finish(tester, h);
  });

  testWidgets('speak automatically (default): speaks on open', (tester) async {
    final h = await boot(tester, const MomentPlayback());
    await open(tester, Moment.evening);
    expect(h.speaker.spoken, hasLength(1));
    await finish(tester, h);
  });

  testWidgets('captions on: the words appear as they are said', (tester) async {
    final h = await boot(tester, const MomentPlayback());
    await open(tester, Moment.evening);
    h.speaker.word(8);
    await tester.pump();
    expect(shown(tester), h.speaker.spoken.single.$1.text.substring(0, 8));
    await finish(tester, h);
  });

  testWidgets('captions off: the words come once the coach has finished', (
    tester,
  ) async {
    final h = await boot(tester, const MomentPlayback(captions: false));
    await open(tester, Moment.evening);
    h.speaker.word(8);
    await tester.pump(const Duration(seconds: 2));
    expect(shown(tester), isEmpty);
    await finish(tester, h);
    expect(shown(tester), h.speaker.spoken.single.$1.text);
  });
}
