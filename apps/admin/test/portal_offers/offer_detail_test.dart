import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/auth/staff.dart';
import 'package:livewell_admin/features/portal_offers/data/portal_offers_api.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';

import '../support/harness.dart';

// Review workflow in the console (D-92). The Core API enforces the same
// rules; these tests check the console offers the right steps.
void main() {
  Finder action(String id) => find.byKey(Key('action-$id'));

  Future<FakePortalOffersApi> open(
    WidgetTester tester,
    StaffSession who,
    PortalOffer o,
  ) async {
    final (_, api) = await pumpAdmin(
      tester,
      session: who,
      offers: [o],
      location: '/offers/${o.id}',
    );
    return api;
  }

  testWidgets('editor, draft: send for review (primary), edit, archive', (
    tester,
  ) async {
    final api = await open(tester, editor, offer('a', rev: 4));
    expect(action('submit'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Send for review'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(action('edit'), findsOneWidget);
    expect(action('archive'), findsOneWidget);
    expect(action('approve'), findsNothing);
    expect(action('publish'), findsNothing);

    await tester.tap(action('submit'));
    await tester.pumpAndSettle();
    expect(api.transitions, [('a', 4, OfferAction.submit)]);
  });

  testWidgets('reviewer, in review by someone else: approve after confirming', (
    tester,
  ) async {
    final o = offer(
      'a',
      status: ReviewStatus.inReview,
      submittedBy: 'ed',
      rev: 2,
    );
    final api = await open(tester, reviewer, o);
    expect(action('approve'), findsOneWidget);
    expect(action('reject'), findsOneWidget);
    expect(action('edit'), findsNothing);
    expect(action('withdraw'), findsNothing);

    await tester.tap(action('approve'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no health-outcome claims'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(api.transitions, isEmpty);

    await tester.tap(action('approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(api.transitions, [('a', 2, OfferAction.approve)]);
  });

  testWidgets('nobody approves their own edits, admins included', (
    tester,
  ) async {
    final o = offer(
      'a',
      status: ReviewStatus.inReview,
      editors: const ['adm'],
      submittedBy: 'ed',
    );
    await open(tester, admin, o);
    expect(action('approve'), findsNothing);
    expect(find.byKey(const Key('own-offer-note')), findsOneWidget);
    // Asking for changes is still possible.
    expect(action('reject'), findsOneWidget);
  });

  testWidgets('editor, in review: waits for a reviewer, can withdraw', (
    tester,
  ) async {
    await open(tester, editor, offer('a', status: ReviewStatus.inReview));
    expect(find.byKey(const Key('waiting-review-note')), findsOneWidget);
    expect(action('approve'), findsNothing);
    expect(action('withdraw'), findsOneWidget);
  });

  testWidgets('editor, approved: publish to the app (editors publish)', (
    tester,
  ) async {
    final o = offer('a', status: ReviewStatus.approved, editors: const []);
    final api = await open(tester, editor, o);
    await tester.tap(action('publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(api.transitions.single.$3, OfferAction.publish);
    expect(find.text('Done: Publish to the app.'), findsOneWidget);
  });

  testWidgets('reviewer, approved: cannot publish', (tester) async {
    final o = offer('a', status: ReviewStatus.approved, editors: const []);
    await open(tester, reviewer, o);
    expect(action('publish'), findsNothing);
  });

  testWidgets('safety reviewer, live offer: only Take offline', (tester) async {
    final o = offer(
      'a',
      status: ReviewStatus.approved,
      active: true,
      editors: const [],
    );
    await open(tester, safetyReviewer, o);
    expect(find.byKey(const Key('live-chip')), findsOneWidget);
    expect(action('unpublish'), findsOneWidget);
    expect(action('archive'), findsNothing);
    expect(action('edit'), findsNothing);
  });

  testWidgets('archived: restore as draft; no edit', (tester) async {
    await open(tester, editor, offer('a', status: ReviewStatus.archived));
    expect(action('restore'), findsOneWidget);
    expect(action('edit'), findsNothing);
  });

  testWidgets('a refused step shows the server message', (tester) async {
    final o = offer('a', status: ReviewStatus.inReview, submittedBy: 'ed');
    final api = await open(tester, reviewer, o);
    api.failNext = const ApiFailure(
      'Someone changed this offer. Reload and try again.',
      reason: 'stale',
    );
    await tester.tap(action('reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-ok')));
    await tester.pumpAndSettle();
    expect(
      find.text('Someone changed this offer. Reload and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows both app previews and the details', (tester) async {
    await open(tester, reviewer, offer('a'));
    expect(find.byKey(const Key('portal-card-preview')), findsNWidgets(2));
    expect(find.text('FROM THE LIVE WELL PORTAL'), findsNWidgets(2));
    expect(find.text(r'$49'), findsWidgets);
  });

  testWidgets('narrow window: details, then the preview', (tester) async {
    final (_, _) = await pumpAdmin(
      tester,
      session: editor,
      offers: [offer('a')],
      location: '/offers/a',
      size: const Size(600, 1000),
    );
    expect(tester.takeException(), isNull);
    expect(action('submit'), findsOneWidget);
  });

  testWidgets('meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(
      tester,
      reviewer,
      offer('a', status: ReviewStatus.inReview, submittedBy: 'ed'),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
