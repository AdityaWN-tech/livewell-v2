import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../home/home_screen_test.dart' show signedIn;

/// Step 4d (D-56): a production account never meets a "coming soon" on a
/// page. Each tab and Profile is scrolled top to bottom and checked (proved
/// to catch Care's and Profile's old rows), and so are the screens pushed
/// from them and Track's Connect Health sheet (Steps 4e/4f, D-61).

final soon = RegExp(r'coming soon|soon you can', caseSensitive: false);

/// Every visible text on the page, scrolled to the end.
Future<Set<String>> pageTexts(WidgetTester tester) async {
  final texts = <String>{};
  void collect() {
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      final s = w.data ?? w.textSpan?.toPlainText();
      if (s != null) texts.add(s);
    }
    for (final e in find.byType(RichText).evaluate()) {
      texts.add((e.widget as RichText).text.toPlainText());
    }
  }

  final scrollable = find.byType(Scrollable).first;
  collect();
  // Long pages build lazily: drag down step by step, collecting as we go.
  for (var i = 0; i < 30; i++) {
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    collect();
  }
  return texts;
}

void main() {
  for (final tab in ['Home', 'Plan', 'Track', 'Learn', 'Care']) {
    testWidgets('$tab: no "coming soon"', (tester) async {
      await signedIn(name: 'Robert Hall').boot(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      final found = [
        for (final t in await pageTexts(tester))
          if (soon.hasMatch(t)) t,
      ];
      expect(found, isEmpty, reason: '$tab says: $found');
    });
  }

  // Screens pushed from the tabs and Profile.
  for (final path in [
    '/plan/framework',
    '/plan/routine',
    '/track/weekly',
    '/learn/library',
    '/learn/breathe',
    '/settings/consents',
  ]) {
    testWidgets('$path: no "coming soon"', (tester) async {
      await signedIn(name: 'Robert Hall').boot(tester);
      GoRouter.of(tester.element(find.byType(NavigationBar))).push(path);
      await tester.pumpAndSettle();
      final found = [
        for (final t in await pageTexts(tester))
          if (soon.hasMatch(t)) t,
      ];
      expect(found, isEmpty, reason: '$path says: $found');
    });
  }

  testWidgets('Track > Connect Health sheet: no "coming soon"', (tester) async {
    await signedIn(name: 'Robert Hall').boot(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Track'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('track-card-steps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-sheet')), findsOneWidget);
    expect(find.textContaining(soon), findsNothing);
  });

  testWidgets('Profile: no "coming soon"', (tester) async {
    await signedIn(name: 'Robert Hall').boot(tester);
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    final found = [
      for (final t in await pageTexts(tester))
        if (soon.hasMatch(t)) t,
    ];
    expect(found, isEmpty, reason: 'Profile says: $found');
  });
}
