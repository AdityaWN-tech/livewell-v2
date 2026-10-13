import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/core/design/tokens.dart';
import 'package:livewell/core/design/typography.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, p) in [
    ('light', LwPalette.light),
    ('dark', LwPalette.dark),
  ]) {
    group('$name palette meets WCAG 2.2 AA (NFR-06)', () {
      final text = {
        'textPrimary on background': (p.textPrimary, p.background),
        'textPrimary on surface': (p.textPrimary, p.surface),
        'textSecondary on background': (p.textSecondary, p.background),
        'textSecondary on surface': (p.textSecondary, p.surface),
        'onPrimary on primary': (p.onPrimary, p.primary),
        'onPrimaryTint on primaryTint': (p.onPrimaryTint, p.primaryTint),
        'onAccent on accent': (p.onAccent, p.accent),
        'textPrimary on accentTint': (p.textPrimary, p.accentTint),
        'primary on surface (links)': (p.primary, p.surface),
        'success on surface': (p.success, p.surface),
        'caution on surface': (p.caution, p.surface),
        'onEmergency on emergency': (p.onEmergency, p.emergency),
      };
      text.forEach((label, pair) {
        test('$label is 4.5:1 or more', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });
      test('outlineStrong on surface is 3:1 or more (input borders)', () {
        expect(contrast(p.outlineStrong, p.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  test('no raw colours outside lib/core/design (use tokens)', () {
    final offenders = <String>[];
    final raw = RegExp(r'Color\(0x|Colors\.[a-z]');
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.contains('lib/core/design/') ||
          path.contains('lib/firebase/')) {
        continue;
      }
      if (raw.hasMatch(f.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });

  test('theme uses Poppins, the palette extension and 48 dp tap targets', () {
    for (final theme in [LwTheme.light(), LwTheme.dark()]) {
      expect(theme.textTheme.bodyLarge?.fontFamily, LwType.fontFamily);
      expect(theme.textTheme.bodyLarge?.fontSize, 16);
      expect(theme.extension<LwPalette>(), isNotNull);
      final min = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(min?.height, greaterThanOrEqualTo(LwSize.minTapTarget));
    }
  });

  testWidgets('LwMotion.duration is zero when reduce-motion is on', (
    tester,
  ) async {
    late Duration seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            seen = LwMotion.duration(context, LwMotion.slow);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, Duration.zero);
  });
}
