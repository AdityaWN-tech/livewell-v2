import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/features/portal_offers/data/portal_offers_api.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';

import '../support/harness.dart';

void main() {
  Finder field(String k) => find.byKey(Key('field-$k'));

  Future<FakePortalOffersApi> openNew(WidgetTester tester) async {
    final (_, api) = await pumpAdmin(
      tester,
      session: editor,
      location: '/offers/new',
    );
    return api;
  }

  testWidgets('new offer: saved as a draft through the API', (tester) async {
    final api = await openNew(tester);
    await tester.enterText(field('title'), 'Sleep reset');
    await tester.enterText(field('description'), 'Four short lessons.');
    await tester.enterText(
      field('url'),
      'https://livewell.conciergeconnectedcare.net/web/courses/sleep',
    );
    await tester.enterText(field('price'), r'$29');
    await tester.enterText(field('topics'), 'Sleep, sleep_hygiene');
    await tester.pumpAndSettle();
    // The preview follows what is typed.
    expect(
      find.descendant(
        of: find.byKey(const Key('portal-card-preview')),
        matching: find.text('Sleep reset'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();

    final f = api.created.single;
    expect(f.title, 'Sleep reset');
    expect(f.priceDisplay, r'$29');
    expect(f.topicTags, ['sleep', 'sleep_hygiene']);
    expect(f.offerType, OfferType.course);
    // Lands on the new offer, as a draft.
    expect(find.text('Draft'), findsOneWidget);
    expect(find.byKey(const Key('action-submit')), findsOneWidget);
  });

  testWidgets('refuses links off the portal, utm parameters and bad tags', (
    tester,
  ) async {
    final api = await openNew(tester);
    await tester.enterText(field('title'), 'Sleep reset');
    await tester.enterText(field('url'), 'https://example.com/course');
    await tester.enterText(field('topics'), 'gut health');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use an https link on'), findsOneWidget);
    expect(find.textContaining('Tags use lowercase'), findsOneWidget);
    expect(api.created, isEmpty);

    await tester.enterText(
      field('url'),
      'https://livewell.conciergeconnectedcare.net/web/courses/x?utm_source=a',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove utm_'), findsOneWidget);
  });

  testWidgets('free lesson: no price, preview says Free lesson', (
    tester,
  ) async {
    await openNew(tester);
    await tester.enterText(field('price'), r'$10');
    await tester.tap(field('type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free lesson').last);
    await tester.pumpAndSettle();
    final price = tester.widget<TextField>(
      find.descendant(of: field('price'), matching: find.byType(TextField)),
    );
    expect(price.enabled, isFalse);
    expect(
      tester.widget<Text>(find.byKey(const Key('preview-price'))).data,
      'Free lesson',
    );
  });

  testWidgets('editing a live offer warns it goes back to review', (
    tester,
  ) async {
    final live = offer(
      'a',
      status: ReviewStatus.approved,
      active: true,
      editors: const [],
      rev: 7,
    );
    final (_, api) = await pumpAdmin(
      tester,
      session: editor,
      offers: [live],
      location: '/offers/a/edit',
    );
    expect(find.byKey(const Key('edit-resets-note')), findsOneWidget);
    expect(find.textContaining('This offer is live'), findsOneWidget);
    await tester.enterText(field('price'), r'$59');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    final (id, rev, fields) = api.updated.single;
    expect((id, rev, fields.priceDisplay), ('a', 7, r'$59'));
  });

  testWidgets('a server refusal is shown on the form', (tester) async {
    final api = await openNew(tester);
    api.failNext = const ApiFailure('Some fields are not valid.');
    await tester.enterText(field('title'), 'Sleep reset');
    await tester.enterText(
      field('url'),
      'https://livewell.conciergeconnectedcare.net/web/courses/sleep',
    );
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-error')), findsOneWidget);
  });

  testWidgets('fields are reachable with Tab in order', (tester) async {
    await openNew(tester);
    await tester.tap(field('title'));
    await tester.pumpAndSettle();
    FocusNode focused() => FocusManager.instance.primaryFocus!;
    final order = <String>[];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final key = find
          .ancestor(
            of: find.byWidgetPredicate(
              (w) => w is EditableText && w.focusNode == focused(),
            ),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('field-'),
            ),
          )
          .evaluate();
      order.add(
        key.isEmpty ? '?' : (key.first.widget.key! as ValueKey<String>).value,
      );
    }
    expect(order, ['field-description', 'field-url', '?']);
  });

  testWidgets('meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openNew(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
