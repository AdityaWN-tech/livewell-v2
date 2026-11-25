import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/learn/domain/lesson.dart';
import 'package:livewell/features/learn/domain/portal.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/learn/presentation/lesson_reader_screen.dart';

import '../home/home_screen_test.dart' show signedIn, today;
import '../support/app_harness.dart';
import 'learn_screen_test.dart' show openLearn;

/// FR-LRN-04 / T-PRT-03 (D-74): the lesson's related portal card at the end
/// of the reader, under the same spec 13.3 rules as the Learn card.
const _offer = PortalOffer(
  id: 'walk-course',
  title: 'Everyday Walking course',
  url: 'https://portal.example/walk?ref=site',
  offerType: 'course',
  priceDisplay: r'$49',
  topicTags: ['movement'],
);

const _lesson = Lesson(
  id: 'l1',
  category: 'Movement',
  title: 'Microhabits',
  cards: ['Small habits need less willpower.', 'Start with 2 minutes.'],
  microhabit: LessonMicrohabit(title: 'Walk for 2 minutes', minutes: 2),
  portalOfferId: 'walk-course',
);

/// Signed in for weeks, flag on, portal consent given, no safety event in
/// 72 h: everything eligible unless a test turns one thing off.
Future<Harness> boot(
  WidgetTester tester, {
  bool flag = true,
  bool consent = true,
  bool safetyClear = true,
  Lesson lesson = _lesson,
  List<PortalOffer> offers = const [_offer],
  CheckIn? checkIn,
}) async {
  final h = signedIn(
    flags: FeatureFlags(portalCards: flag),
    createdAt: DateTime(2026, 9, 1),
  );
  if (consent) {
    await h.consents.record(ConsentType.portalLinking, granted: true);
  }
  if (checkIn != null) h.checkIns.days[today] = checkIn;
  h.safetyClear = safetyClear;
  h.learn.lessons = [lesson];
  h.learn.offers = offers;
  await h.boot(tester);
  return h;
}

/// Opens the lesson and goes to its last page.
Future<void> toLessonEnd(WidgetTester tester, {String id = 'l1'}) async {
  await openLearn(tester);
  final open = find.byKey(Key('lesson-$id'));
  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
  expect(find.byType(LessonReaderScreen), findsOneWidget);
  while (find.byKey(const Key('lesson-next')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('lesson-next')));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const Key('lesson-end')), findsOneWidget);
}

Finder inReader(Finder f) =>
    find.descendant(of: find.byKey(const Key('lesson-end')), matching: f);

Future<void> scrollToCard(WidgetTester tester) async {
  await tester.ensureVisible(inReader(find.byKey(const Key('portal-not-now'))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('eligible: after the microhabit, labelled, secondary to '
      'Finish; card_shown once a day for the offer', (tester) async {
    final h = await boot(tester);
    await toLessonEnd(tester);
    expect(find.byKey(const Key('lesson-microhabit')), findsOneWidget);
    expect(inReader(find.byKey(const Key('portal-card'))), findsOneWidget);
    expect(find.text('Go deeper on the Live Well Portal'), findsOneWidget);
    expect(inReader(find.text('FROM THE LIVE WELL PORTAL')), findsOneWidget);
    expect(inReader(find.text(r'$49')), findsOneWidget);

    // Below the microhabit.
    final habit = tester.getTopLeft(find.byKey(const Key('lesson-microhabit')));
    final card = tester.getTopLeft(
      inReader(find.byKey(const Key('portal-card'))),
    );
    expect(card.dy, greaterThan(habit.dy));

    // Finish stays the page's only filled (primary) button.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const Key('lesson-finish')), findsOneWidget);
    await scrollToCard(tester);
    final view = tester.getSize(inReader(find.byKey(const Key('portal-view'))));
    final notNow = tester.getSize(
      inReader(find.byKey(const Key('portal-not-now'))),
    );
    expect(notNow, view, reason: 'Not now is as visible as View course');

    // Learn showed the same card first today; seeing it again at the
    // lesson end doesn't count twice (the caps count days).
    final shown = h.learn.events.where((e) => e.event == 'card_shown');
    expect(shown.map((e) => e.offerId), ['walk-course']);
  });

  testWidgets('View course: UTM and lw_cid on the link, the click is logged '
      'with ids only', (tester) async {
    final h = await boot(tester);
    await toLessonEnd(tester);
    await scrollToCard(tester);
    await tester.tap(inReader(find.byKey(const Key('portal-view'))));
    await tester.pumpAndSettle();

    final url = h.browser.opened.single;
    expect(url.host, 'portal.example');
    expect(url.path, '/walk');
    expect(url.queryParameters, {
      'ref': 'site',
      'utm_source': 'livewell_app',
      'utm_medium': 'avatar',
      'utm_campaign': 'lesson_end',
      'utm_content': 'walk-course',
      'lw_cid': h.learn.clickIds.single,
    });
    expect(h.learn.clickIds.single, matches(RegExp(r'^[0-9a-f]{16}$')));
    final clicked = h.learn.events.where((e) => e.event == 'clicked').single;
    expect(clicked.offerId, 'walk-course');
    expect(h.learn.surfaces.last, 'lesson_end');
  });

  testWidgets('first seen in the reader: card_shown is logged for '
      'lesson_end', (tester) async {
    // Opened straight from a link (livewell://), so Learn never showed it.
    final h = await boot(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen)))
        .push(LearnItemScreen.pathFor('l1'));
    await tester.pumpAndSettle();
    while (find.byKey(const Key('lesson-next')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('lesson-next')));
      await tester.pumpAndSettle();
    }
    expect(inReader(find.byKey(const Key('portal-card'))), findsOneWidget);
    final shown = h.learn.events.where((e) => e.event == 'card_shown').single;
    expect(shown.offerId, 'walk-course');
    expect(h.learn.surfaces, ['lesson_end']);
  });

  testWidgets('Not now hides it (14-day cooldown)', (tester) async {
    final h = await boot(tester);
    await toLessonEnd(tester);
    await scrollToCard(tester);
    await tester.tap(inReader(find.byKey(const Key('portal-not-now'))));
    await tester.pumpAndSettle();
    expect(inReader(find.byKey(const Key('portal-card'))), findsNothing);
    expect(find.text('Go deeper on the Live Well Portal'), findsNothing);
    expect(
      h.learn.events.where((e) => e.event == 'dismissed').single.offerId,
      'walk-course',
    );
    expect(find.byKey(const Key('lesson-finish')), findsOneWidget);
  });

  group('hidden, and nothing logged for the reader, when', () {
    Future<void> expectHidden(WidgetTester tester, Harness h) async {
      await toLessonEnd(tester);
      expect(find.byKey(const Key('lesson-microhabit')), findsOneWidget);
      expect(inReader(find.byKey(const Key('portal-card'))), findsNothing);
      expect(find.text('Go deeper on the Live Well Portal'), findsNothing);
      expect(h.learn.surfaces, isNot(contains('lesson_end')));
    }

    testWidgets('the portalCards flag is off', (tester) async {
      await expectHidden(tester, await boot(tester, flag: false));
    });

    testWidgets('there is no portal consent', (tester) async {
      await expectHidden(tester, await boot(tester, consent: false));
    });

    testWidgets('a safety event in the last 72 hours (or unknown)', (
      tester,
    ) async {
      await expectHidden(tester, await boot(tester, safetyClear: false));
    });

    testWidgets('it is a gentle day', (tester) async {
      await expectHidden(
        tester,
        await boot(
          tester,
          checkIn: const CheckIn(date: today, mood: 1, gentleDay: true),
        ),
      );
    });

    testWidgets('the lesson has no related offer', (tester) async {
      await expectHidden(
        tester,
        await boot(
          tester,
          lesson: const Lesson(
            id: 'l1',
            category: 'Movement',
            title: 'Microhabits',
            cards: ['Only card.'],
            microhabit: LessonMicrohabit(title: 'Walk for 2 minutes'),
          ),
        ),
      );
    });

    testWidgets('the related offer is not active and approved', (tester) async {
      const other = PortalOffer(
        id: 'sleep-course',
        title: 'Sleep course',
        url: 'https://portal.example/sleep',
        offerType: 'course',
      );
      await expectHidden(tester, await boot(tester, offers: [other]));
    });

    testWidgets('another card was already shown today (1 a day)', (
      tester,
    ) async {
      final h = signedIn(
        flags: const FeatureFlags(portalCards: true),
        createdAt: DateTime(2026, 9, 1),
      );
      await h.consents.record(ConsentType.portalLinking, granted: true);
      h.safetyClear = true;
      h.learn.lessons = [_lesson];
      h.learn.offers = [_offer];
      h.learn.events.add(
        PortalEventRecord(
          event: 'card_shown',
          offerId: 'other-offer',
          at: Harness.defaultNow.subtract(const Duration(hours: 1)),
        ),
      );
      await h.boot(tester);
      await expectHidden(tester, h);
    });
  });
}
