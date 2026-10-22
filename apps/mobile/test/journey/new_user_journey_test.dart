import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/features/auth/presentation/sign_in_screen.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/avatar/presentation/avatar_screen.dart';
import 'package:livewell/features/focus/presentation/focus_screen.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/onboarding/presentation/why_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';
import 'package:livewell/features/starter_plan/presentation/plan_preview_screen.dart';
import 'package:livewell/features/voice/domain/voice.dart';
import 'package:livewell/features/voice/presentation/voice_screen.dart';
import 'package:livewell/features/welcome/presentation/welcome_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-ONB-03 "Done when": the whole new-user journey, end to end, on the
/// current (T-UI-02) screens: fresh install → sign in with Google → default
/// avatar → default voice OK → Why → mood → focus → 7-day plan → Home →
/// Profile → dark mode → log out. The dev build, where pending plan
/// templates may be used (prod waits for clinical approval).

/// A pause after each step, for the screen recording on a device
/// (integration_test/new_user_journey_test.dart). Zero in widget tests,
/// where time is fake.
Duration journeyPause = Duration.zero;

/// Called after every step with the step's name, to save a frame for the
/// walkthrough video (test/journey/journey_frames_test.dart). Null otherwise.
Future<void> Function(WidgetTester tester, String step)? journeyOnStep;

Future<void> pauseForViewer() async {
  if (journeyPause > Duration.zero) await Future<void>.delayed(journeyPause);
}

Future<void> _step(WidgetTester tester, String name) async {
  await journeyOnStep?.call(tester, name);
}

/// Taps [f], scrolling the page to it first when it isn't built yet.
Future<void> tapFinder(WidgetTester tester, Finder f) async {
  // Not built yet: look further down, then back up.
  for (final delta in [200.0, -200.0]) {
    if (f.evaluate().isNotEmpty) break;
    try {
      await tester.scrollUntilVisible(
        f,
        delta,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    } on StateError {
      // Reached the end without finding it: try the other way.
    }
  }
  f = f.first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
  await pauseForViewer();
  await _step(tester, 'tap');
}

Future<void> tapKey(WidgetTester tester, String key) =>
    tapFinder(tester, find.byKey(Key(key)));

Future<void> tapLabel(WidgetTester tester, String text) =>
    tapFinder(tester, find.text(text));

/// Ticks every legal document (the list is built lazily, so scroll down
/// and tick what appears, as a person would), then accepts.
Future<void> acceptLegal(WidgetTester tester) async {
  Finder unticked() =>
      find.byWidgetPredicate((w) => w is CheckboxListTile && w.value != true);
  for (var round = 0; round < 12; round++) {
    if (unticked().evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      if (unticked().evaluate().isEmpty) break;
      continue;
    }
    await tester.ensureVisible(unticked().first);
    await tester.pumpAndSettle();
    await tester.tap(unticked().first);
    await tester.pumpAndSettle();
  }
  await tapLabel(tester, 'Accept and continue');
}

/// Runs the journey; [scale] is the phone's text size.
Future<Harness> runJourney(WidgetTester tester, {double scale = 1}) async {
  if (scale != 1) {
    tester.view
      ..physicalSize = const Size(750, 1334)
      ..devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
  final h = Harness(
    flavor: Flavor.dev,
    // Fresh install: nothing saved, not asked anything yet.
    checkInPrompt: FakeCheckInPromptStore(),
  );
  await h.boot(tester);

  // 1. Welcome → What Live Well does → 18+ → legal (PR #10, kept).
  expect(find.byType(WelcomeScreen), findsOneWidget);
  await _step(tester, 'welcome');
  await tapLabel(tester, 'Get started');
  await tapLabel(tester, 'Continue');
  await tapLabel(tester, "Yes, I'm 18 or older");
  await acceptLegal(tester);

  // 2. Sign up with the Google icon (ONB-03a).
  expect(find.byType(SignInScreen), findsOneWidget);
  await tapKey(tester, 'sign-in-google');
  const uid = 'google:1';
  expect(h.profiles.created.keys, [uid]);

  // 3. Meet your coach (ONB-03b): a ready-made coach (T-AVT-08b).
  expect(find.byType(AvatarScreen), findsOneWidget);
  await tapKey(tester, 'coach-brown_hair');
  await tapKey(tester, 'studio-save-avatar');
  expect(h.avatars.saved, CoachChoice.fallback);

  // 4. The default voice: "Sounds good" (ONB-03c).
  expect(find.byType(VoiceScreen), findsOneWidget);
  expect(h.player.played.first.$1, VoiceLibrary.greetingAsset);
  await tapKey(tester, 'voice-ok');
  expect(h.voices.chosen, VoiceChoice.fallback);

  // 5. Your Why (PR #12).
  expect(find.byType(WhyScreen), findsOneWidget);
  await tester.enterText(
    find.byKey(const Key('why')),
    'To play with my grandkids',
  );
  await tester.pumpAndSettle();
  await _step(tester, 'why');
  await tapLabel(tester, 'Save my Why');

  // 6. Mood first (T-DLY-02), then what to work on (ONB-03d).
  await tester.tap(find.byKey(const Key('checkin-option-0-4')));
  await tester.pumpAndSettle();
  await tapLabel(tester, 'Skip for now');
  expect(find.byType(FocusScreen), findsOneWidget);
  await tapKey(tester, 'focus-sleep_better');
  await tapKey(tester, 'focus-continue');

  // 7. Your 7 days (ONB-03e), reminders allowed.
  expect(find.byType(PlanPreviewScreen), findsOneWidget);
  await tapKey(tester, 'plan-start');
  await tapLabel(tester, 'Allow reminders');
  expect(h.plans.days, hasLength(7));
  expect(h.reminders.scheduled, isNotEmpty);

  // 8. Home, right after the first sign-up, with today's step
  // from the plan and the Why (it used to stay "signed out" until a
  // restart: signedInUidProvider).
  expect(find.byType(HomeScreen), findsOneWidget);
  await tester.scrollUntilVisible(
    find.byKey(const Key('step-open')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.byKey(const Key('step-open')), findsOneWidget);
  await tester.scrollUntilVisible(
    find.text('To play with my grandkids'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('To play with my grandkids'), findsOneWidget);
  await _step(tester, 'home');
  return h;
}

void main() {
  testWidgets('fresh install to Home, then Profile, dark mode and log out', (
    tester,
  ) async {
    final h = await runJourney(tester);

    // 9. Profile (ONB-03f): dark mode, then log out.
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tapKey(tester, 'profile-theme');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tapKey(tester, 'profile-logout');
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(h.auth.signedIn, isNull);
    expect(h.reminders.scheduled, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('the same journey at text 2.0 on an iPhone SE', (tester) async {
    await runJourney(tester, scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('killing the app mid-journey resumes at the same step', (
    tester,
  ) async {
    final h = Harness(
      flavor: Flavor.dev,
      checkInPrompt: FakeCheckInPromptStore(),
    );
    await h.boot(tester);
    await tapLabel(tester, 'Get started');
    await tapLabel(tester, 'Continue');
    await tapLabel(tester, "Yes, I'm 18 or older");
    await acceptLegal(tester);
    await tapKey(tester, 'sign-in-google');
    await tapKey(tester, 'coach-short_curls');
    await tapKey(tester, 'studio-save-avatar');
    // Restart while on the voice step: it opens again, not Welcome.
    await h.boot(tester);
    expect(find.byType(VoiceScreen), findsOneWidget);
  });
}
