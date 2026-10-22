@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';

import '../home/home_screen_test.dart' show bootPreview;
import 'moment_screen_test.dart' show finish, open;

/// The Avatar Moment player (T-DLY-03b) golden images: the morning,
/// step-done and gentle moments after speaking, light and dark, text at
/// 100%, 130% and 200%, on an iPhone SE. Regenerate after an intended
/// change:
///   flutter test --update-goldens --tags golden
void main() {
  const size = Size(750, 1334);
  const dpr = 2.0;
  for (final m in [Moment.morning, Moment.stepDone, Moment.gentle]) {
    for (final dark in [false, true]) {
      for (final (label, scale) in [
        ('normal', 1.0),
        ('medium', 1.3),
        ('large', 2.0),
      ]) {
        final name = 'moment_${m.file}_${dark ? 'dark' : 'light'}_$label';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final h = await bootPreview(tester);
          await open(tester, m);
          await finish(tester, h);
          final needed = size.height / dpr * (1 + (scale - 1) * 1.2);
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
