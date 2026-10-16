import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_screen_test.dart' show bootPreview;

/// The shared tab header (T-UI-02b): on every tab, at text sizes 1.0, 1.3
/// and 2.0, on a small phone (iPhone SE, 375 x 667) and a large one: the
/// title on the left, the profile button at the top right on the same row,
/// and buttons and status pills on a row below the title.
void main() {
  const phones = {
    'iPhone SE': (Size(750, 1334), 2.0),
    'large phone': (Size(1080, 2400), 2.625),
  };
  for (final MapEntry(key: phone, value: (size, dpr)) in phones.entries) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('header on every tab ($phone, text $scale)', (tester) async {
        await bootPreview(tester);
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = dpr;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpAndSettle();
        final width = size.width / dpr;
        for (final tab in ['Home', 'Plan', 'Track', 'Learn', 'Care']) {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(tab),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);

          final title = tester.getRect(
            find.byKey(const Key('tab-header-title')),
          );
          final profile = tester.getRect(
            find.byKey(const Key('profile-button')),
          );
          // Top right, same row as the title.
          expect(profile.right, closeTo(width - 16, 1), reason: '$tab right');
          expect(profile.top, lessThan(title.bottom), reason: '$tab row');
          expect(
            profile.left,
            greaterThanOrEqualTo(title.right - 0.5),
            reason: '$tab title and profile must not overlap',
          );
          expect(profile.top, closeTo(title.top, 8), reason: '$tab top');
          // Buttons and pills: below the title, never beside it.
          final actions = find.byKey(const Key('tab-header-actions'));
          if (actions.evaluate().isNotEmpty) {
            expect(
              tester.getRect(actions).top,
              greaterThanOrEqualTo(title.bottom),
              reason: '$tab actions',
            );
          }
        }
      });
    }
  }
}
