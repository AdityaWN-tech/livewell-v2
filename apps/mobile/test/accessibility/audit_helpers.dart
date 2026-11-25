import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WCAG 2.2 AA checks Flutter can automate (T-REL-01): tap targets of
/// 48dp (Android) and 44pt (iOS), a label on every tap target, and text
/// contrast of 4.5:1 (3:1 for large text).
final auditGuidelines = <String, AccessibilityGuideline>{
  'android tap target': androidTapTargetGuideline,
  'iOS tap target': iOSTapTargetGuideline,
  'labeled tap target': labeledTapTargetGuideline,
  'text contrast': textContrastGuideline,
};

/// The main vertical list of the page (the one that scrolls furthest).
Finder? mainScrollable(WidgetTester tester) {
  Element? best;
  double bestExtent = 0;
  for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.axisDirection != AxisDirection.down) continue;
    final p = s.position;
    if (!p.hasContentDimensions) continue;
    final extent = p.maxScrollExtent - p.pixels;
    if (best == null || extent > bestExtent) {
      best = e;
      bestExtent = extent;
    }
  }
  if (best == null) return null;
  final target = best;
  return find.byElementPredicate((e) => e == target);
}

/// Runs [check] on what is on screen, then scrolls down a screenful at a
/// time and runs it again, to the end of the page.
Future<void> acrossPage(
  WidgetTester tester,
  Future<void> Function(int screenful) check, {
  int maxScreens = 12,
}) async {
  await check(0);
  for (var i = 1; i < maxScreens; i++) {
    final scrollable = mainScrollable(tester);
    if (scrollable == null) return;
    final state = tester.state<ScrollableState>(scrollable);
    final before = state.position.pixels;
    if (before >= state.position.maxScrollExtent) return;
    await tester.drag(scrollable, const Offset(0, -450));
    await tester.pumpAndSettle();
    if (state.position.pixels == before) return;
    await check(i);
  }
}

/// Failures of [auditGuidelines] across the whole page, as readable lines.
Future<List<String>> auditFailures(WidgetTester tester) async {
  final failures = <String>[];
  await acrossPage(tester, (screen) async {
    for (final MapEntry(key: name, value: g) in auditGuidelines.entries) {
      final result = await g.evaluate(tester);
      if (!result.passed) {
        failures.add('[$name @ screen $screen] ${result.reason}');
      }
    }
  });
  return failures;
}
