@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/learn/domain/lesson.dart';

import '../home/home_screen_test.dart' show bootPreview, signedIn;
import 'learn_screen_test.dart' show lesson, openLearn;

/// Learn (T-UI-02f) golden images: a real account with a few approved
/// items (no portal card, D-22) and the dev preview (pick up, featured,
/// portal card, audio), light and dark, text at 100%, 130% and 200%, on a
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
        for (final state in ['catalog', 'preview']) {
          if (phone == 'se' && state != 'preview') continue;
          final prefix = phone == 'se' ? 'learn_se' : 'learn';
          final name = '${prefix}_${state}_${dark ? 'dark' : 'light'}_$label';
          testWidgets(name, (tester) async {
            tester.platformDispatcher.platformBrightnessTestValue = dark
                ? Brightness.dark
                : Brightness.light;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            if (state == 'catalog') {
              final h = signedIn();
              h.learn.lessons = [
                lesson(1),
                lesson(2),
                lesson(3, kind: LessonKind.audio),
              ];
              await h.boot(tester);
            } else {
              await bootPreview(tester);
            }
            await openLearn(tester);
            // Tall enough that the whole screen is in the image.
            final needed = size.height / dpr * (2.2 + (scale - 1) * 4.0);
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
