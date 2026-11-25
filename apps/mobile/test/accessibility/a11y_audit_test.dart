import 'package:flutter/material.dart';

import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/routing/router.dart';

import 'audit_helpers.dart';
import 'prod_routes.dart';

/// T-REL-01 accessibility audit (WCAG 2.2 AA, NFR-06), automated part. The
/// report is docs/audit/2026-11-19-accessibility.md; what needs a person
/// with VoiceOver / TalkBack is listed there.
///
/// For every route the prod flavour registers:
/// - light and dark: 48 dp / 44 pt tap targets, a label on every tap
///   target, text contrast, a heading, and no tap target without a role;
/// - text at 200% (WCAG 1.4.4), 260% (phone at 200% x the app's "Largest")
///   and 310% (iOS's largest accessibility size) on an iPhone SE: nothing
///   overflows and no text is cut off (D-89).

/// Text contrast false positives: the guideline samples the whole tile, so
/// a check-in answer's outline and face outnumber its label's pixels. The
/// label is textPrimary on surface (>= 4.5:1, test/design/tokens_test.dart).
const _contrastFalsePositives = {
  '/onboarding/checkin': ['"Good"', '"Okay"', '"Great"', '"Low"', '"Very'],
};

/// Screens with no title by design: an Avatar Moment is the coach and its
/// captions, read in order.
const _noHeading = {'/moment/:name'};

/// All paths the router registers for [flavor], with `:params`.
Set<String> registeredPaths(Flavor flavor) {
  final container = ProviderContainer(
    overrides: [flavorProvider.overrideWithValue(flavor)],
  );
  addTearDown(container.dispose);
  final paths = <String>{};
  void walk(List<RouteBase> routes, String parent) {
    for (final r in routes) {
      var base = parent;
      if (r is GoRoute) {
        base = r.path.startsWith('/')
            ? r.path
            : '${parent == '/' ? '' : parent}/${r.path}';
        paths.add(base);
      }
      walk(r.routes, base);
    }
  }

  walk(container.read(routerProvider).configuration.routes, '/');
  return paths;
}

/// Semantics problems a guideline doesn't catch: tappable nodes with no
/// role (read as just "double tap to activate"), and the heading count.
({List<String> noRole, int headings}) semanticsScan(WidgetTester tester) {
  final noRole = <String>[];
  var headings = 0;
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    final f = d.flagsCollection;
    if (f.isHeader) headings++;
    final hasRole =
        f.isButton ||
        f.isLink ||
        f.isTextField ||
        f.isSlider ||
        f.isInMutuallyExclusiveGroup ||
        f.isChecked != CheckedState.none ||
        f.isToggled != Tristate.none;
    // The modal barrier behind a sheet is Flutter's own ("Scrim").
    if (d.hasAction(SemanticsAction.tap) && !hasRole && d.label != 'Scrim') {
      noRole.add('"${d.label}"');
    }
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  final root = tester.binding.rootPipelineOwner;
  void owners(PipelineOwner o) {
    final r = o.semanticsOwner?.rootSemanticsNode;
    if (r != null) visit(r);
    o.visitChildren(owners);
  }

  owners(root);
  return (noRole: noRole, headings: headings);
}

/// Text cut off with an ellipsis or maxLines on screen now.
List<String> clippedText(WidgetTester tester) => [
  for (final e in find.byType(RichText).hitTestable().evaluate())
    if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
      (e.renderObject! as RenderParagraph).text.toPlainText(),
];

void main() {
  test('the sweep covers every route the prod flavour registers', () {
    // The splash is the only one left out: it shows for a moment and moves
    // on by itself (its reduce-motion path: test/splash/splash_test.dart).
    expect({
      for (final r in prodRoutes) r.name,
      '/splash',
    }, registeredPaths(Flavor.prod));
  });

  test('developer routes are not registered in prod', () {
    expect(
      registeredPaths(Flavor.prod).where((p) => p.startsWith('/dev')),
      isEmpty,
    );
  });

  group('WCAG checks, light and dark', () {
    for (final route in prodRoutes) {
      for (final dark in [false, true]) {
        testWidgets('${route.name} ${dark ? 'dark' : 'light'}', (tester) async {
          final semantics = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await openRoute(tester, route);

          final allowed = _contrastFalsePositives[route.name] ?? const [];
          final failures = <String>[];
          final noRole = <String>{};
          var headings = 0;
          await acrossPage(tester, (screen) async {
            for (final MapEntry(key: name, value: g)
                in auditGuidelines.entries) {
              final result = await g.evaluate(tester);
              if (result.passed) continue;
              final reasons = (result.reason ?? '')
                  .split('\n\n')
                  .where(
                    (r) =>
                        r.trim().isNotEmpty &&
                        !(name == 'text contrast' &&
                            allowed.any((a) => r.contains('label: $a'))),
                  );
              failures.addAll(reasons.map((r) => '[$name] $r'));
            }
            final scan = semanticsScan(tester);
            noRole.addAll(scan.noRole);
            headings += scan.headings;
          });
          expect(failures, isEmpty, reason: failures.join('\n'));
          expect(noRole, isEmpty, reason: 'tap targets without a role');
          if (!_noHeading.contains(route.name)) {
            expect(headings, greaterThan(0), reason: 'no heading');
          }
          semantics.dispose();
        });
      }
    }
  });

  group('large text: no overflow, nothing cut off (iPhone SE)', () {
    for (final route in prodRoutes) {
      for (final scale in [2.0, 2.6, 3.1]) {
        testWidgets('${route.name} at ${(scale * 100).round()}%', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await openRoute(tester, route);
          tester.view
            ..physicalSize = const Size(750, 1334)
            ..devicePixelRatio = 2.0;
          await tester.pumpAndSettle();
          final clipped = <String>{};
          await acrossPage(tester, (_) async {
            // A RenderFlex overflow fails the test on its own.
            clipped.addAll(clippedText(tester));
          }, maxScreens: 30);
          expect(clipped, isEmpty, reason: 'text cut off');
        });
      }
    }
  });
}
