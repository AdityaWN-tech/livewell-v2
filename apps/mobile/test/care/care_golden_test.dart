@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import 'care_screen_test.dart' show openCare, openTab;

/// Care (T-UI-02g) golden images: a real account (coach coming soon), its
/// Safety tab, and the dev preview (sample conversation, AI voice), light
/// and dark, text at 100%, 130% and 200%, on a large phone and an iPhone
/// SE. Regenerate after an intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  const phones = {
    'phone': (Size(1080, 2400), 2.625),
    'se': (Size(750, 1334), 2.0),
  };
  for (final MapEntry(key: phone, value: (size, dpr)) in phones.entries) {
    for (final dark in [false, true]) {
      for (final (label, scale) in [
        ('normal', 1.0),
        ('medium', 1.3),
        ('large', 2.0),
      ]) {
        for (final state in ['chat', 'safety', 'preview']) {
          if (phone == 'se' && state != 'preview') continue;
          final prefix = phone == 'se' ? 'care_se' : 'care';
          final name = '${prefix}_${state}_${dark ? 'dark' : 'light'}_$label';
          testWidgets(name, (tester) async {
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            if (state == 'preview') {
              await bootPreview(tester);
            } else {
              final h = signedIn();
              h.profiles.regions['u1'] = 'IN';
              await h.boot(tester);
            }
            await openCare(tester);
            if (state == 'safety') await openTab(tester, 'safety');
            // Tall enough that the whole screen is in the image.
            final needed = size.height / dpr * (1.8 + (scale - 1) * 3.4);
            tester.view
              ..physicalSize = Size(size.width, needed * dpr)
              ..devicePixelRatio = dpr;
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/$name.png'),
            );
          });
        }
      }
    }
  }
}
