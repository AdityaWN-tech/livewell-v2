import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';

import '../support/harness.dart';

void main() {
  final offers = [
    offer('draft', title: 'Draft offer'),
    offer('review', title: 'Waiting offer', status: ReviewStatus.inReview),
    offer(
      'live',
      title: 'Live offer',
      status: ReviewStatus.approved,
      active: true,
      editors: const [],
    ),
    offer('old', title: 'Old offer', status: ReviewStatus.archived),
  ];

  testWidgets('lists offers with their status; Live in app only when live', (
    tester,
  ) async {
    await pumpAdmin(tester, session: editor, offers: offers);
    expect(find.text('Draft offer'), findsOneWidget);
    expect(find.text('Waiting offer'), findsOneWidget);
    expect(find.text('Live offer'), findsOneWidget);
    // Archived offers are under their own filter.
    expect(find.text('Old offer'), findsNothing);
    expect(find.byKey(const Key('live-chip')), findsOneWidget);
    expect(find.text('In review'), findsWidgets);
    expect(find.byKey(const Key('offer-new')), findsOneWidget);
  });

  testWidgets('filters', (tester) async {
    await pumpAdmin(tester, session: reviewer, offers: offers);
    await tester.tap(find.byKey(const Key('filter-needsReview')));
    await tester.pumpAndSettle();
    expect(find.text('Waiting offer'), findsOneWidget);
    expect(find.text('Draft offer'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Old offer'), findsOneWidget);
    expect(find.text('Live offer'), findsNothing);
  });

  testWidgets('a row opens the offer', (tester) async {
    await pumpAdmin(tester, session: reviewer, offers: offers);
    await tester.tap(find.text('Waiting offer'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portal-card-preview')), findsNWidgets(2));
  });

  testWidgets('empty catalog', (tester) async {
    await pumpAdmin(tester, session: editor);
    expect(find.text('No offers yet.'), findsOneWidget);
  });

  testWidgets('meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAdmin(tester, session: editor, offers: offers);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
