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

typedef _Lab = (double, double, double);

_Lab _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

/// CIEDE2000 colour difference. About 10 or more reads as a different colour.
double deltaE2000(Color a, Color b) => _de2000Lab(_lab(a), _lab(b));

double _de2000Lab(_Lab p1, _Lab p2) {
  double rad(double d) => d * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;
  final (l1, a1, b1) = p1;
  final (l2, a2, b2) = p2;
  final cBar =
      (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
  final c7 = math.pow(cBar, 7);
  final g = 0.5 * (1 - math.sqrt(c7 / (c7 + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  double hue(double b, double a) =>
      (b == 0 && a == 0) ? 0 : (deg(math.atan2(b, a)) + 360) % 360;
  final h1p = hue(b1, a1p), h2p = hue(b2, a2p);
  final dLp = l2 - l1, dCp = c2p - c1p;
  var dh = h2p - h1p;
  if (c1p * c2p == 0) {
    dh = 0;
  } else if (dh > 180) {
    dh -= 360;
  } else if (dh < -180) {
    dh += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dh / 2));
  final lBar = (l1 + l2) / 2, cBarP = (c1p + c2p) / 2;
  double hBar;
  if (c1p * c2p == 0) {
    hBar = h1p + h2p;
  } else if ((h1p - h2p).abs() > 180) {
    hBar = (h1p + h2p + (h1p + h2p < 360 ? 360 : -360)) / 2;
  } else {
    hBar = (h1p + h2p) / 2;
  }
  final t =
      1 -
      0.17 * math.cos(rad(hBar - 30)) +
      0.24 * math.cos(rad(2 * hBar)) +
      0.32 * math.cos(rad(3 * hBar + 6)) -
      0.20 * math.cos(rad(4 * hBar - 63));
  final dTheta = 30 * math.exp(-math.pow((hBar - 275) / 25, 2));
  final cp7 = math.pow(cBarP, 7);
  final rc = 2 * math.sqrt(cp7 / (cp7 + math.pow(25, 7)));
  final sl =
      1 +
      0.015 * math.pow(lBar - 50, 2) / math.sqrt(20 + math.pow(lBar - 50, 2));
  final sc = 1 + 0.045 * cBarP, sh = 1 + 0.015 * cBarP * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}

List<(String, Color)> _tints(LwPalette p) => [
  ('mint', p.mint),
  ('lime', p.lime),
  ('lavender', p.lavender),
  ('peach', p.peach),
  ('sky', p.sky),
  ('butter', p.butter),
  ('rose', p.rose),
  ('heroSurface', p.heroSurface),
  ('accentTint', p.accentTint),
];

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
        'textSecondary on primaryTint': (p.textSecondary, p.primaryTint),
        'onPrimary on primary': (p.onPrimary, p.primary),
        'onPrimaryTint on primaryTint': (p.onPrimaryTint, p.primaryTint),
        'onAccentStrong on accentStrong (buttons)': (
          p.onAccentStrong,
          p.accentStrong,
        ),
        'accentStrong on surface (links)': (p.accentStrong, p.surface),
        'accentStrong on background (links)': (p.accentStrong, p.background),
        'onAccentTint on accentTint': (p.onAccentTint, p.accentTint),
        'onHeroSurface on heroSurface': (p.onHeroSurface, p.heroSurface),
        'onHeroSurfaceSecondary on heroSurface': (
          p.onHeroSurfaceSecondary,
          p.heroSurface,
        ),
        'primary on surface': (p.primary, p.surface),
        'success on surface': (p.success, p.surface),
        'caution on surface': (p.caution, p.surface),
        'onEmergency on emergency': (p.onEmergency, p.emergency),
        // T-UI-02: grey chips, deep green on mint, and every pastel card.
        'textPrimary on surfaceMuted (chips)': (p.textPrimary, p.surfaceMuted),
        'textSecondary on surfaceMuted': (p.textSecondary, p.surfaceMuted),
        'primaryDark on primaryTint': (p.primaryDark, p.primaryTint),
        'primaryDark on surface': (p.primaryDark, p.surface),
        // Tab screens sit on the mint-to-sky wash.
        for (final (end, c) in [
          ('washTop', p.washTop),
          ('washBottom', p.washBottom),
        ]) ...{
          'textPrimary on $end': (p.textPrimary, c),
          'textSecondary on $end': (p.textSecondary, c),
          'accentStrong on $end (links)': (p.accentStrong, c),
          'primary on $end': (p.primary, c),
        },
        for (final (tint, c) in _tints(p)) ...{
          'onTint on $tint': (p.onTint, c),
          'onTintSecondary on $tint': (p.onTintSecondary, c),
          'primaryDark on $tint': (p.primaryDark, c),
        },
      };
      text.forEach((label, pair) {
        test('$label is 4.5:1 or more', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });
      // WCAG 1.4.11: icons, dots, progress bars and input borders.
      final nonText = {
        'outlineStrong on surface (input borders)': (
          p.outlineStrong,
          p.surface,
        ),
        'accent on surface (icons, dots)': (p.accent, p.surface),
        'accent on background': (p.accent, p.background),
        'accent on heroSurface': (p.accent, p.heroSurface),
        'primary on surfaceMuted (selected vs unselected chip)': (
          p.primary,
          p.surfaceMuted,
        ),
        'primary on background (focus ring, active tab)': (
          p.primary,
          p.background,
        ),
      };
      nonText.forEach((label, pair) {
        test('$label is 3:1 or more', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(3));
        });
      });
      test('emergency red is clearly different from every other colour '
          '(CIEDE2000 >= 15)', () {
        for (final c in [
          p.primary,
          p.accent,
          p.accentStrong,
          p.caution,
          p.success,
          for (final (_, t) in _tints(p)) t,
        ]) {
          expect(deltaE2000(p.emergency, c), greaterThanOrEqualTo(15));
        }
      });
      test('the 7 pastel tints are told apart (CIEDE2000 >= 3)', () {
        final t = _tints(p);
        for (var i = 0; i < t.length; i++) {
          for (var j = i + 1; j < t.length; j++) {
            if (t[i].$2 == t[j].$2) continue;
            expect(
              deltaE2000(t[i].$2, t[j].$2),
              greaterThanOrEqualTo(3),
              reason: '${t[i].$1} vs ${t[j].$1}',
            );
          }
        }
      });
    });
  }

  test('CIEDE2000 matches published reference pairs', () {
    // Sharma, Wu, Dalal (2005) test data, pairs 1 and 17, in Lab.
    expect(
      _de2000Lab((50, 2.6772, -79.7751), (50, 0, -82.7485)),
      closeTo(2.0425, 1e-3),
    );
    expect(_de2000Lab((50, 2.5, 0), (73, 25, -18)), closeTo(27.1492, 1e-3));
  });

  test('filled buttons use the AA green, not the brighter chart green', () {
    for (final (theme, p) in [
      (LwTheme.light(), LwPalette.light),
      (LwTheme.dark(), LwPalette.dark),
    ]) {
      final style = theme.filledButtonTheme.style!;
      expect(style.backgroundColor?.resolve({}), p.accentStrong);
      expect(style.foregroundColor?.resolve({}), p.onAccentStrong);
      expect(p.accentStrong, isNot(p.accent));
    }
  });

  test('selected chips and segments are solid green with a light label', () {
    for (final (theme, p) in [
      (LwTheme.light(), LwPalette.light),
      (LwTheme.dark(), LwPalette.dark),
    ]) {
      const sel = {WidgetState.selected};
      expect(theme.chipTheme.color?.resolve(sel), p.primary);
      expect(theme.chipTheme.color?.resolve({}), p.surfaceMuted);
      final label = theme.chipTheme.labelStyle!.color! as WidgetStateColor;
      expect(label.resolve(sel), p.onPrimary);
      expect(label.resolve({}), p.textPrimary);
      final seg = theme.segmentedButtonTheme.style!;
      expect(seg.backgroundColor?.resolve(sel), p.primary);
      expect(seg.foregroundColor?.resolve(sel), p.onPrimary);
    }
  });

  test('cards are 24 dp round, buttons 16 dp (T-UI-02)', () {
    final theme = LwTheme.light();
    final card = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(card.borderRadius, BorderRadius.circular(LwRadius.card));
    final button =
        theme.filledButtonTheme.style!.shape!.resolve({})!
            as RoundedRectangleBorder;
    expect(button.borderRadius, BorderRadius.circular(LwRadius.button));
    expect(LwRadius.card, 24);
    expect(LwRadius.button, 16);
  });

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
