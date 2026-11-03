@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_screen_test.dart' show bootPreview;
import '../support/app_harness.dart';
import 'polish_test.dart' show signedIn;

/// T-UI-02i golden images for the screens without their own text-size
/// set: Welcome (with the tour), Profile, Today's reminders, Get help now
/// and Home after Done (the coach celebrates), light and dark, text at 100%, 130% and 200%, on an iPhone SE.
/// Regenerate after an intended visual change:
///   flutter test --update-goldens --tags golden
void main() {
  const size = Size(750, 1334);
  const dpr = 2.0;
  final screens = <String, Future<void> Function(WidgetTester)>{
    'welcome': (tester) => Harness().boot(tester),
    'profile': (tester) async {
      await signedIn().boot(tester);
      await tester.tap(find.byKey(const Key('profile-button')));
      await tester.pumpAndSettle();
    },
    'reminders': (tester) async {
      await signedIn().boot(tester);
      await tester.tap(find.byKey(const Key('home-bell')));
      await tester.pumpAndSettle();
    },
    'done': (tester) async {
      await bootPreview(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('step-open')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-open')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('step-done')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('step-done')));
      await tester.pump();
      // Skip the celebration (it has its own goldens, T-DLY-03d).
      await tester.tap(find.byKey(const Key('celebration')));
      await tester.pumpAndSettle();
      // Back to the top, where the coach is.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
    },
    'help': (tester) async {
      final h = signedIn();
      h.profiles.regions['u1'] = 'IN';
      await h.boot(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Care'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-help-now')));
      await tester.pumpAndSettle();
    },
  };
  for (final MapEntry(key: screen, value: open) in screens.entries) {
    for (final dark in [false, true]) {
      for (final (label, scale) in [
        ('normal', 1.0),
        ('medium', 1.3),
        ('large', 2.0),
      ]) {
        final name = '${screen}_se_${dark ? 'dark' : 'light'}_$label';
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await open(tester);
          // Tall enough for the whole screen (Profile is long).
          final factor = screen == 'profile' ? 5.0 : 1.4;
          final needed = size.height / dpr * (factor + (scale - 1) * factor);
          tester.view
            ..physicalSize = Size(size.width, needed * dpr)
            ..devicePixelRatio = dpr;
          await tester.pumpAndSettle();
          // Let images (the logo) finish decoding before the snapshot.
          await tester.runAsync(() async {
            for (final e in find.byType(Image).evaluate()) {
              await precacheImage((e.widget as Image).image, e);
            }
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
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
