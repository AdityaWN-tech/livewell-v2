import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/home/data/name_prompt.dart';
import 'package:livewell/features/home/domain/home_models.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const uid = 'u1';
const today = '2026-10-14';
const previewLabel = 'Preview the app (dev build only)';

/// Signed in and past onboarding; check-in already asked today.
Harness signedIn({
  Flavor flavor = Flavor.prod,
  FeatureFlags flags = const FeatureFlags(),
  String? name,
  DateTime? createdAt,
  String? why,
  bool nameAsked = true,
  DateTime? now,
}) {
  final h = Harness(
    flavor: flavor,
    flags: flags,
    now: now,
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
    namePrompt: FakeNamePromptStore(wasAsked: nameAsked),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  if (name != null) h.profiles.names[uid] = name;
  if (createdAt != null) h.profiles.createdAts[uid] = createdAt;
  if (why != null) h.profiles.whys[uid] = why;
  return h;
}

/// Dev build, "Preview the app": the only place sample data appears.
Future<Harness> bootPreview(WidgetTester tester, {CheckIn? checkIn}) async {
  final h = Harness(flavor: Flavor.dev);
  if (checkIn != null) h.checkIns.days[today] = checkIn;
  await h.boot(tester);
  await tester.tap(find.text(previewLabel));
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  return h;
}

Finder inHome(Finder f) =>
    find.descendant(of: find.byType(HomeScreen), matching: f);

/// FR-DLY-03: at most 1 primary and 2 secondary actions on Home. The step
/// card (it opens Done) and the 4 check-in tiles (one check-in) are the two
/// secondaries; Done itself is in the step's sheet.
void expectActionLimit() {
  final primary = inHome(find.byType(FilledButton)).evaluate().length;
  final secondary =
      inHome(find.byType(TextButton)).evaluate().length +
      inHome(find.byType(OutlinedButton)).evaluate().length +
      inHome(find.byKey(const Key('home-checkin-card'))).evaluate().length +
      inHome(find.byKey(const Key('step-open'))).evaluate().length;
  expect(primary, lessThanOrEqualTo(1), reason: 'primary actions');
  expect(secondary, lessThanOrEqualTo(2), reason: 'secondary actions');
}

String tileValue(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(Key('home-tile-$id-value'))).data!;

const gentleStep =
    'A small, gentle step will appear here. Go easy on yourself today.';

void main() {
  group('dayNumber', () {
    test('day 1 on the day the account was made, counted by calendar day', () {
      final created = DateTime(2026, 10, 6, 23, 50);
      expect(dayNumber(created, DateTime(2026, 10, 6, 23, 59)), 1);
      expect(dayNumber(created, DateTime(2026, 10, 7, 0, 5)), 2);
      expect(dayNumber(created, DateTime(2026, 10, 14, 8, 30)), 9);
    });

    test('a daylight-saving change does not skip or repeat a day', () {
      // US clocks go back on 2026-11-01.
      expect(dayNumber(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 3);
    });
  });

  group('gentleReasonFor', () {
    test('matches the reason, never guesses', () {
      CheckIn c(int mood, int? stress, bool gentle) =>
          CheckIn(date: today, mood: mood, stress: stress, gentleDay: gentle);
      expect(gentleReasonFor(c(4, 2, false)), isNull);
      expect(gentleReasonFor(c(1, null, true)), GentleReason.lowMood);
      expect(gentleReasonFor(c(5, 4, true)), GentleReason.highStress);
      expect(gentleReasonFor(c(2, 5, true)), GentleReason.both);
      expect(gentleReasonFor(c(3, 2, true)), GentleReason.other);
    });
  });

  group('real account (prod): only real data', () {
    testWidgets('empty state: greeting, coach, before-check-in step, tiles', (
      tester,
    ) async {
      await signedIn(name: 'Robert Hall').boot(tester);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.textContaining('Good morning, Robert!'), findsOneWidget);
      expect(find.text('Ready for a healthier, happier you?'), findsOneWidget);
      expect(
        find.text("Hi, Robert! Let's make today a good day."),
        findsOneWidget,
      );
      expect(find.text('Coach'), findsOneWidget);
      expect(
        find.text(
          'Check in first. Then a small step picked for you will appear here.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-checkin-card')), findsOneWidget);
      for (final id in ['mood', 'energy', 'sleep', 'stress']) {
        expect(tileValue(tester, id), 'Tap to log');
      }
      expect(
        find.text('Your streak starts with your first step.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your progress will show here once you start your first habit.',
        ),
        findsOneWidget,
      );
      // No plan yet: nothing to open, and no sample data.
      expect(find.byKey(const Key('step-open')), findsNothing);
      expect(find.textContaining('Priya'), findsNothing);
      expect(find.textContaining('walk after lunch'), findsNothing);
      expect(find.byKey(const Key('home-day')), findsNothing);
      expectActionLimit();
    });

    for (final (hour, greeting, icon) in [
      (8, 'Good morning, Robert!', Icons.wb_sunny_rounded),
      (14, 'Good afternoon, Robert!', Icons.wb_sunny_rounded),
      (20, 'Good evening, Robert!', Icons.nightlight_round),
      (2, 'Good evening, Robert!', Icons.nightlight_round),
    ]) {
      testWidgets('greeting by time of day ($hour:05)', (tester) async {
        await signedIn(
          name: 'Robert Hall',
          now: DateTime(2026, 10, 14, hour, 5),
        ).boot(tester);
        expect(find.textContaining(greeting), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byKey(const Key('home-greeting-icon'))).icon,
          icon,
        );
      });
    }

    testWidgets('no name: a friendly greeting without one', (tester) async {
      await signedIn().boot(tester);
      expect(find.textContaining('Good morning!'), findsOneWidget);
      expect(find.text("Hi! Let's make today a good day."), findsOneWidget);
    });

    group('the name is asked once', () {
      testWidgets('saved: Home says "Hi, {first name}", not asked again', (
        tester,
      ) async {
        final h = signedIn(nameAsked: false);
        await h.boot(tester);
        expect(find.text('What should your coach call you?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('home-name-field')),
          'Asha',
        );
        await tester.tap(find.byKey(const Key('home-name-save')));
        await tester.pumpAndSettle();
        expect(h.profiles.names[uid], 'Asha');
        expect(h.namePrompt.wasAsked, isTrue);
        expect(find.byKey(const Key('home-name-prompt')), findsNothing);
        expect(
          find.text("Hi, Asha! Let's make today a good day."),
          findsOneWidget,
        );
        expect(find.textContaining('Good morning, Asha!'), findsOneWidget);
      });

      testWidgets('"Not now": never asked again, nothing saved', (
        tester,
      ) async {
        final h = signedIn(nameAsked: false);
        await h.boot(tester);
        await tester.tap(find.byKey(const Key('home-name-skip')));
        await tester.pumpAndSettle();
        expect(h.namePrompt.wasAsked, isTrue);
        expect(h.profiles.names[uid], isNull);
        expect(find.byKey(const Key('home-name-prompt')), findsNothing);
      });

      testWidgets('not a name: a kind error, nothing saved', (tester) async {
        final h = signedIn(nameAsked: false);
        await h.boot(tester);
        await tester.enterText(
          find.byKey(const Key('home-name-field')),
          '1234',
        );
        await tester.tap(find.byKey(const Key('home-name-save')));
        await tester.pumpAndSettle();
        expect(
          find.text('Please use letters only (up to 30).'),
          findsOneWidget,
        );
        expect(h.profiles.names[uid], isNull);
      });

      testWidgets('a name from Google or Apple: never asked', (tester) async {
        await signedIn(name: 'Robert Hall', nameAsked: false).boot(tester);
        expect(find.byKey(const Key('home-name-prompt')), findsNothing);
      });

      test('first names: letters in any script, no digits or symbols', () {
        for (final ok in [
          'Asha',
          'Jean-Luc',
          'O\'Neil',
          'Zoë',
          'प्रिया',
          'Mary Ann',
        ]) {
          expect(isValidFirstName(ok), isTrue, reason: ok);
        }
        for (final bad in ['', ' ', '1234', 'a@b', '-Asha', 'x' * 31]) {
          expect(isValidFirstName(bad), isFalse, reason: bad);
        }
      });
    });

    testWidgets('Day N comes from when the account was created', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await signedIn(createdAt: DateTime(2026, 10, 6, 9)).boot(tester);
      expect(find.text('Day 9'), findsOneWidget);
      expect(find.bySemanticsLabel('Day 9 of your journey'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the Why is shown in a compact card', (tester) async {
      await signedIn(why: 'To play with my grandkids').boot(tester);
      expect(find.text('YOUR WHY'), findsOneWidget);
      expect(find.text('To play with my grandkids'), findsOneWidget);
    });

    testWidgets('checked in today: tiles show the answers in full words', (
      tester,
    ) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 4,
        energy: 5,
        stress: 5,
        timeAvailable: 10,
        gentleDay: true,
      );
      await h.boot(tester);
      expect(tileValue(tester, 'mood'), 'Good');
      expect(tileValue(tester, 'energy'), 'High');
      expect(tileValue(tester, 'sleep'), 'Skipped');
      // Full words, never "Very" on its own (phone bug).
      expect(tileValue(tester, 'stress'), 'Very high');
      expectActionLimit();
    });

    testWidgets('checked in, not gentle: a supportive line and the time', (
      tester,
    ) async {
      final h = signedIn();
      h.checkIns.days[today] = const CheckIn(
        date: today,
        mood: 4,
        timeAvailable: 10,
        gentleDay: false,
      );
      await h.boot(tester);
      expect(
        find.text('Love that energy. Let\'s use it well today.'),
        findsOneWidget,
      );
      expect(
        find.text('A step that fits in 10 minutes will appear here.'),
        findsOneWidget,
      );
    });

    // The gentle-day message matches the reason (phone bug).
    for (final (name, checkIn, line) in [
      (
        'low mood',
        const CheckIn(date: today, mood: 1, gentleDay: true),
        'Thanks for telling me. Low days happen, and they pass. '
            'Let\'s keep today gentle.',
      ),
      (
        'high stress',
        const CheckIn(date: today, mood: 4, stress: 5, gentleDay: true),
        'Thanks for telling me. Stress is high today, so let\'s keep things '
            'calm and simple.',
      ),
      (
        'low mood and high stress',
        const CheckIn(date: today, mood: 2, stress: 4, gentleDay: true),
        'Thanks for telling me. Feeling low and stressed is a lot. '
            'Let\'s go slowly today.',
      ),
      (
        'a red flag in the note (D-24)',
        const CheckIn(date: today, mood: 3, stress: 2, gentleDay: true),
        'Thanks for telling me. Let\'s keep today gentle.',
      ),
    ]) {
      testWidgets('gentle day, $name: matching words', (tester) async {
        final h = signedIn();
        h.checkIns.days[today] = checkIn;
        await h.boot(tester);
        expect(find.text(line), findsOneWidget);
        expect(find.text('Hi. Let\'s keep today gentle.'), findsOneWidget);
        expect(find.text(gentleStep), findsOneWidget);
      });
    }

    for (final id in ['mood', 'energy', 'sleep', 'stress']) {
      testWidgets('the $id tile opens the mood-first check-in', (tester) async {
        await signedIn().boot(tester);
        await tester.tap(find.byKey(Key('home-tile-$id')));
        await tester.pumpAndSettle();
        expect(find.text('Hi, how are you feeling today?'), findsOneWidget);
      });
    }

    testWidgets('briefing flag off: the tagline, no player', (tester) async {
      await signedIn().boot(tester);
      expect(find.byKey(const Key('home-briefing')), findsNothing);
      expect(find.text('Small steps. Brighter days.'), findsOneWidget);
    });

    testWidgets('briefing flag on: a "coming soon" row, nothing plays', (
      tester,
    ) async {
      await signedIn(flags: const FeatureFlags(briefings: true)).boot(tester);
      expect(find.byKey(const Key('home-briefing')), findsOneWidget);
      expect(find.text('Briefing coming soon'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-briefing')),
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );
    });
  });

  group('dev preview: sample data', () {
    testWidgets('shows the full design with sample data', (tester) async {
      final handle = tester.ensureSemantics();
      await bootPreview(tester);
      expect(find.text('Day 9'), findsOneWidget);
      expect(find.textContaining('Good morning, Priya!'), findsOneWidget);
      expect(
        find.text('Hi, Priya! Let\'s make today a good day.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('coach-avatar-waving')), findsOneWidget);
      expect(find.text('10-min walk after lunch'), findsOneWidget);
      expect(find.text('Driver 3'), findsOneWidget);
      expect(find.text('14 Day Streak'), findsOneWidget);
      expect(find.text('Keep going!'), findsOneWidget);
      expect(find.text('Phase 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('7 of 9 habits kept'), findsOneWidget);
      expectActionLimit();
      handle.dispose();
    });

    testWidgets('the step opens with Done and "Make it 5 min"', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('step-sheet')), findsOneWidget);
      expect(find.byKey(const Key('step-done')), findsOneWidget);
      expect(find.text('Make it 5 min'), findsOneWidget);
    });

    testWidgets('"Make it 5 min" swaps in the smaller step', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-smaller')));
      await tester.pumpAndSettle();
      expect(find.text('5-min walk after lunch'), findsOneWidget);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('step-smaller')), findsNothing);
    });

    testWidgets('Done: a kind confirmation on the card', (tester) async {
      await bootPreview(tester);
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('step-done-message')), findsOneWidget);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.byKey(const Key('step-open')), findsNothing);
    });

    for (final (name, checkIn, reason) in [
      (
        'low mood',
        const CheckIn(date: today, mood: 1, gentleDay: true),
        'Feeling low? A small step still counts.',
      ),
      (
        'high stress',
        const CheckIn(date: today, mood: 4, stress: 5, gentleDay: true),
        'A calm, easy step for a stressful day.',
      ),
      (
        'both',
        const CheckIn(date: today, mood: 2, stress: 4, gentleDay: true),
        'Go easy on yourself. The smallest step is plenty.',
      ),
    ]) {
      testWidgets('gentle day ($name): smaller step, its own reason', (
        tester,
      ) async {
        await bootPreview(tester, checkIn: checkIn);
        expect(find.text('5-min walk after lunch'), findsOneWidget);
        expect(find.text(reason), findsOneWidget);
        expectActionLimit();
        await tester.tap(find.byKey(const Key('step-open')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('step-smaller')), findsNothing);
      });
    }
  });

  group('accessibility (NFR-06)', () {
    for (final dark in [false, true]) {
      testWidgets(
        'labels, tap targets and contrast (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final handle = tester.ensureSemantics();
          await bootPreview(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(
            find.bySemanticsLabel('Mood: Tap to log. Opens the check-in.'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(
              'Today\'s next step: 10-min walk after lunch. Opens Done and a '
              'smaller option.',
            ),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel('Your coach'), findsOneWidget);
          handle.dispose();
        },
      );
    }

    for (final dark in [false, true]) {
      testWidgets(
        'status bar icons are readable (${dark ? 'dark' : 'light'})',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await signedIn().boot(tester);
          final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find
                .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                )
                .first,
          );
          expect(
            region.value.statusBarIconBrightness,
            dark ? Brightness.light : Brightness.dark,
          );
        },
      );
    }

    // Small phone and large text: tiles go 2 across so words never break.
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('iPhone SE, text $scale: no overflow, whole words', (
        tester,
      ) async {
        final h = signedIn(name: 'Robert Hall');
        h.checkIns.days[today] = const CheckIn(
          date: today,
          mood: 1,
          energy: 1,
          sleep: 1,
          stress: 5,
          gentleDay: true,
        );
        await h.boot(tester);
        tester.view
          ..physicalSize = const Size(750, 1334)
          ..devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const Key('home-tile-stress-value')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        for (final id in ['mood', 'energy', 'sleep', 'stress']) {
          final value = find.byKey(Key('home-tile-$id-value'));
          final para = tester.renderObject<RenderParagraph>(value);
          // Every word fits on a line: none is split mid-word.
          for (final w in tileValue(tester, id).split(' ')) {
            final tp = TextPainter(
              text: TextSpan(text: w, style: para.text.style),
              textDirection: TextDirection.ltr,
              textScaler: para.textScaler,
            )..layout();
            expect(
              tp.width,
              lessThanOrEqualTo(para.size.width + 0.5),
              reason: '$id "$w" at $scale',
            );
          }
        }
      });
    }
  });
}
