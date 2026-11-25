import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/design/theme.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';
import 'package:livewell_admin/features/portal_offers/presentation/portal_card_preview.dart';

void main() {
  OfferFields f({OfferType type = OfferType.course, String price = ''}) =>
      OfferFields(
        title: 'Gut health',
        url: 'https://livewell.conciergeconnectedcare.net/web/courses/gut',
        offerType: type,
        priceDisplay: price,
      );

  test(
    'price label (spec 13.4): as entered, else Paid course; free says so',
    () {
      expect(PortalCardPreview.priceLabel(f(price: r'$49')), r'$49');
      expect(PortalCardPreview.priceLabel(f()), 'Paid course');
      expect(
        PortalCardPreview.priceLabel(f(type: OfferType.program)),
        'Paid course',
      );
      expect(
        PortalCardPreview.priceLabel(f(type: OfferType.freeLesson)),
        'Free lesson',
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'labelled, both buttons, announced as a preview (dark: $dark)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? LwTheme.dark() : LwTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    PortalCardPreview(fields: f(price: r'$49')),
                    PortalCardPreview(fields: f(), secondary: true),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('FROM THE LIVE WELL PORTAL'), findsNWidgets(2));
        expect(find.text('View course'), findsNWidgets(2));
        expect(find.text('Not now'), findsNWidgets(2));
        expect(
          find.bySemanticsLabel(RegExp('Preview of the app card')),
          findsNWidgets(2),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }
}
