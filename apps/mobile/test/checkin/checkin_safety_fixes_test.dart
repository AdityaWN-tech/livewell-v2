import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/checkin/presentation/checkin_sheet.dart';
import 'package:livewell/features/dev/application/preview_mode.dart';
import 'package:livewell/features/learn/application/learn_data.dart';
import 'package:livewell/features/moments/application/coach_state.dart';
import 'package:livewell/features/safety/data/safety_event_store.dart';
import 'package:livewell/features/safety/data/safety_rules_provider.dart';
import 'package:livewell/features/safety/domain/safety_rules.dart';
import 'package:livewell/features/safety/presentation/safety_screens.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import 'checkin_flow_test.dart' show answerAll, fresh, held, pick, today, uid;

/// Regression tests for the T-DLY-02 safety fixes (D-70).
/// HUMAN REVIEW REQUIRED (safety).
Future<void> closeSheet(WidgetTester tester) async {
  // Swipe down / back: the sheet closes without "Done".
  Navigator.of(tester.element(find.byType(CheckInSheet))).pop();
  await tester.pumpAndSettle();
}

Future<void> typeNote(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('checkin-barrier')), text);
  await tester.pump();
  await tapText(tester, 'Done');
}

void main() {
  group('saved as it goes', () {
    testWidgets('closed right after mood: the mood is kept', (tester) async {
      final h = fresh();
      await h.boot(tester);
      await pick(tester, 0, 4);
      await closeSheet(tester);
      expect(find.byType(CheckInSheet), findsNothing);
      final saved = h.checkIns.days[today]!;
      expect(saved.mood, 4);
      expect(saved.gentleDay, isFalse);
      expect(saved.barrierText, isNull);
    });

    testWidgets('closed after a low mood: today is already a gentle day', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      await pick(tester, 0, 1);
      await closeSheet(tester);
      expect(h.checkIns.days[today]!.gentleDay, isTrue);
    });

    testWidgets('closed after high stress: answers so far kept, gentle', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      await pick(tester, 0, 5);
      await pick(tester, 1, 3);
      await pick(tester, 2, 4);
      await pick(tester, 3, 5);
      await closeSheet(tester);
      final saved = h.checkIns.days[today]!;
      expect(
        [saved.mood, saved.energy, saved.sleep, saved.stress],
        [5, 3, 4, 5],
      );
      expect(saved.gentleDay, isTrue);
      expect(h.checkIns.days.keys, [today], reason: 'one record per day');
    });

    testWidgets('a typed note is never saved early, only after the check', (
      tester,
    ) async {
      final h = fresh();
      await h.boot(tester);
      await answerAll(tester, mood: 4);
      await tester.enterText(
        find.byKey(const Key('checkin-barrier')),
        'Long meeting day',
      );
      await tester.pump();
      await closeSheet(tester);
      expect(h.checkIns.days[today]!.barrierText, isNull);
    });
  });

  group('a gentle day stays gentle', () {
    testWidgets('redo the same day with a great mood', (tester) async {
      final h = fresh();
      await h.boot(tester);
      await pick(tester, 0, 1);
      await tapText(tester, 'Skip for now');
      expect(h.checkIns.days[today]!.gentleDay, isTrue);

      // Open the check-in again from Home's tiles and answer Great.
      final card = find.byKey(const Key('home-checkin-card'));
      await tester.ensureVisible(card);
      await tester.tap(
        find.descendant(of: card, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckInSheet), findsOneWidget);
      await pick(tester, 0, 5);
      await tapText(tester, 'Skip for now');
      final saved = h.checkIns.days[today]!;
      expect(saved.mood, 5);
      expect(saved.gentleDay, isTrue);
    });
  });

  group('crisis in the note', () {
    testWidgets('the gentle day is saved before the card is closed', (
      tester,
    ) async {
      final h = fresh(region: 'US');
      await h.boot(tester);
      await answerAll(tester, mood: 4);
      await typeNote(tester, "I don't want to be alive anymore");
      expect(find.byType(SafetyInterruptScreen), findsOneWidget);
      // Still on the card (the app could be closed now).
      final saved = h.checkIns.days[today]!;
      expect(saved.gentleDay, isTrue);
      expect(saved.barrierText, isNull, reason: 'the words are never kept');
      expect(saved.mood, 4);
      // Only the time is recorded on the phone (D-70).
      expect(h.safetyEvents.last, isNotNull);
      expect(held(tester), isTrue);
    });

    testWidgets('the card shows at once when the profile is slow', (
      tester,
    ) async {
      final h = fresh(region: 'IN');
      await h.boot(tester);
      await answerAll(tester);
      await typeNote(tester, 'Main marna chahta hoon');
      expect(find.text('Call Tele-MANAS: 14416'), findsOneWidget);
    });
  });

  group('the safety hold survives a restart', () {
    testWidgets('an event earlier today: the coach stays quiet', (
      tester,
    ) async {
      final h = Harness(
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
        checkInPrompt: FakeCheckInPromptStore(today),
        safetyEvents: InMemorySafetyEventStore(DateTime(2026, 10, 14, 7)),
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      await h.boot(tester);
      expect(held(tester), isTrue);
    });

    testWidgets('an event yesterday: no hold today', (tester) async {
      final h = Harness(
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
        checkInPrompt: FakeCheckInPromptStore(today),
        safetyEvents: InMemorySafetyEventStore(DateTime(2026, 10, 13, 22)),
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      await h.boot(tester);
      expect(held(tester), isFalse);
    });
  });

  group('safety rules cannot be loaded', () {
    testWidgets('not stuck: a message to try again; the note is not saved; '
        'today counts as gentle', (tester) async {
      final h = Harness(
        auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
        checkInPrompt: FakeCheckInPromptStore(),
        overrides: [
          safetyRulesProvider.overrideWith(
            (ref) => Future<SafetyRules>.error(StateError('asset missing')),
          ),
        ],
      );
      h.profiles.existing[uid] = ProfileStep.assessment;
      await h.boot(tester);
      await answerAll(tester, mood: 4);
      await typeNote(tester, 'Long meeting day');

      expect(
        find.text(
          "We couldn't check your note just now, so it wasn't saved. "
          'Your other answers are saved.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // Still on the note step and usable (not stuck saving).
      expect(find.byType(CheckInSheet), findsOneWidget);
      final done = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Done'),
      );
      expect(done.onPressed, isNotNull);
      final saved = h.checkIns.days[today]!;
      expect(saved.barrierText, isNull);
      expect(saved.gentleDay, isTrue);
      expect(saved.mood, 4);
    });
  });

  group('portal cards (spec 15.3, FR-SAF-07)', () {
    test('today still loading or unreadable counts as gentle', () {
      expect(portalGentleDay(const AsyncLoading()), isTrue);
      expect(
        portalGentleDay(AsyncError(StateError('offline'), StackTrace.empty)),
        isTrue,
      );
      expect(portalGentleDay(const AsyncData(null)), isFalse);
      expect(
        portalGentleDay(
          const AsyncData(CheckIn(date: today, mood: 4, gentleDay: false)),
        ),
        isFalse,
      );
      expect(
        portalGentleDay(
          const AsyncData(CheckIn(date: today, mood: 4, gentleDay: true)),
        ),
        isTrue,
      );
    });

    Future<ProviderContainer> container(DateTime now, DateTime? last) async {
      final c = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          previewModeProvider.overrideWith(() => _PreviewOn()),
          safetyEventStoreProvider.overrideWithValue(
            InMemorySafetyEventStore(last),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(safetyHoldStoreProvider.future);
      return c;
    }

    final event = DateTime(2026, 10, 14, 9);

    test(
      '72 hours after a safety event: cards stay off, then come back',
      () async {
        Future<bool> clearAt(Duration after) async => (await container(
          event.add(after),
          event,
        )).read(safetyClearProvider);
        expect(await clearAt(const Duration(hours: 1)), isFalse);
        expect(await clearAt(const Duration(hours: 71, minutes: 59)), isFalse);
        expect(await clearAt(const Duration(hours: 72)), isTrue);
        // A clock set back before the event still counts as recent.
        expect(await clearAt(const Duration(hours: -5)), isFalse);
      },
    );

    test('no event ever: clear in the dev preview', () async {
      final c = await container(event, null);
      expect(c.read(safetyClearProvider), isTrue);
    });

    test('the phone record still loading: not clear', () {
      final c = ProviderContainer(
        overrides: [
          previewModeProvider.overrideWith(() => _PreviewOn()),
          safetyEventStoreProvider.overrideWithValue(_NeverLoads()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(recentSafetyEventProvider), isTrue);
      expect(c.read(safetyClearProvider), isFalse);
    });

    test(
      'real accounts: never clear until the server record exists (D-22)',
      () async {
        final c = ProviderContainer(
          overrides: [
            safetyEventStoreProvider.overrideWithValue(
              InMemorySafetyEventStore(),
            ),
          ],
        );
        addTearDown(c.dispose);
        await c.read(safetyHoldStoreProvider.future);
        expect(c.read(safetyClearProvider), isFalse);
      },
    );
  });
}

class _PreviewOn extends PreviewMode {
  @override
  bool build() => true;
}

class _NeverLoads implements SafetyEventStore {
  @override
  Future<DateTime?> lastEventAt() => Completer<DateTime?>().future;

  @override
  Future<void> recordEvent(DateTime at) async {}
}
