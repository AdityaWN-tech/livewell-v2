@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/voice/domain/voice.dart';

import 'studio_test.dart' show openStudio, signedIn, tapKey;

/// The Avatar & Voice Studio (T-UI-02h) golden images: the Avatar, Voice
/// and Background tabs, light and dark, text at 100%, 130% and 200%, on a
/// large phone and an iPhone SE. Regenerate after an intended change:
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
        for (final tab in ['avatar', 'voice', 'background']) {
          if (phone == 'se' && tab != 'avatar') continue;
          final prefix = phone == 'se' ? 'studio_se' : 'studio';
          final name = '${prefix}_${tab}_${dark ? 'dark' : 'light'}_$label';
          testWidgets(name, (tester) async {
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            final h = signedIn();
            h.voices.chosen = const VoiceChoice(voiceId: 'lw-warm');
            await h.boot(tester);
            await openStudio(tester);
            if (tab != 'avatar') await tapKey(tester, 'studio-tab-$tab');
            await tester.drag(
              find.byType(Scrollable).last,
              const Offset(0, 5000),
            );
            // Tall enough that the whole screen is in the image.
            final needed = size.height / dpr * (1.8 + (scale - 1) * 3.6);
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
