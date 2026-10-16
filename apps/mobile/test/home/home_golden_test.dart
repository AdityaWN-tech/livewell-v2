@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/checkin/domain/checkin.dart';

import 'home_screen_test.dart' show bootPreview, signedIn, today;

/// Home (T-UI-02c) golden images: a real new account (empty states), the
/// dev preview (sample data) and a gentle day (high stress), light and
/// dark, text at 100%, 130% and 200%, on a large phone and an iPhone SE.
/// Regenerate after an intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  const phones = {
    // 412 x 915 dp and 375 x 667 dp.
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
        for (final state in ['empty', 'preview', 'gentle']) {
          // The small phone: the sample screen is enough.
          if (phone == 'se' && state != 'preview') continue;
          final prefix = phone == 'se' ? 'home_se' : 'home';
          final name =
              '${prefix}_${state}_${dark ? 'dark' : 'light'}_$label';
          testWidgets(name, (tester) async {
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            switch (state) {
              case 'empty':
                await signedIn(
                  name: 'Robert Hall',
                  createdAt: DateTime(2026, 10, 14, 7),
                ).boot(tester);
              case 'gentle':
                await bootPreview(
                  tester,
                  checkIn: const CheckIn(
                    date: today,
                    mood: 4,
                    energy: 3,
                    sleep: 2,
                    stress: 5,
                    gentleDay: true,
                  ),
                );
              default:
                await bootPreview(tester);
            }
            // Tall enough that the whole screen is in the image.
            final logicalHeight = size.height / dpr;
            final needed = logicalHeight * (1.2 + (scale - 1) * 2.6);
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
