@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn, today;
import 'track_screen_test.dart' show day, openTrack;

/// Track (T-UI-02e) golden images: a real account with a few check-ins
/// (no Health connected) and the dev preview (Health samples), light and
/// dark, text at 100%, 130% and 200%, on a large phone and an iPhone SE.
/// Regenerate after an intended visual change:
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
        for (final state in ['checkins', 'preview']) {
          if (phone == 'se' && state != 'preview') continue;
          final prefix = phone == 'se' ? 'track_se' : 'track';
          final name = '${prefix}_${state}_${dark ? 'dark' : 'light'}_$label';
          testWidgets(name, (tester) async {
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            if (state == 'checkins') {
              final h = signedIn();
              for (final c in [
                day('2026-10-12', 4, sleep: 4, stress: 2),
                day('2026-10-13', 3, sleep: 3, stress: 3),
                day(today, 4, sleep: 5, stress: 2),
              ]) {
                h.checkIns.days[c.date] = c;
              }
              await h.boot(tester);
            } else {
              await bootPreview(tester);
            }
            await openTrack(tester);
            // Tall enough that the whole screen is in the image.
            final needed = size.height / dpr * (2.0 + (scale - 1) * 3.4);
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
