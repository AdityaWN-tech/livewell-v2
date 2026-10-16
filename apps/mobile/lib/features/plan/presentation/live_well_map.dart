import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/plan_models.dart';

/// The Live Well Map (T-UI-02d): 8 driver segments around "Live Well".
/// Each segment fills outwards with its 30-day completion (FR-GAM-02);
/// before the assessment the whole wheel is soft grey. Below it, one row per
/// driver: the accessible, text-size-proof way to open a driver (the wheel
/// can be tapped too).
class LiveWellMap extends StatelessWidget {
  const LiveWellMap({
    super.key,
    required this.drivers,
    required this.completion,
    required this.onOpen,
  });

  final List<Driver> drivers;

  /// 0..1 per driver, or null before the 10-minute check.
  final List<double>? completion;
  final void Function(Driver driver) onOpen;

  /// The segment fills, in wheel order (never colour alone: each segment
  /// also has its number and a labelled row below).
  static List<Color> segmentColours(LwPalette p) => [
    p.rose,
    p.lavender,
    p.sky,
    p.mint,
    p.butter,
    p.peach,
    p.lime,
    p.sky,
  ];

  /// Which segment a point falls in, measured clockwise from the top.
  static int? segmentAt(Offset local, Size size, int count) {
    final c = size.center(Offset.zero);
    final v = local - c;
    final r = v.distance;
    final outer = size.shortestSide / 2;
    if (r > outer || r < outer * _hole) return null;
    final angle = (math.atan2(v.dy, v.dx) + math.pi / 2) % (2 * math.pi);
    return (angle / (2 * math.pi / count)).floor() % count;
  }

  static const _hole = 0.32;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final c = completion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, 280.0);
            final size = Size.square(side);
            return Center(
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const Key('plan-map-wheel'),
                  onTapUp: (d) {
                    final i = segmentAt(d.localPosition, size, drivers.length);
                    if (i != null) onOpen(drivers[i]);
                  },
                  child: SizedBox.fromSize(
                    size: size,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: size,
                          painter: _WheelPainter(
                            colours: c == null
                                ? List.filled(drivers.length, p.surfaceMuted)
                                : segmentColours(p),
                            fill: c,
                            deep: p.primaryDark,
                            gap: p.surface,
                            hole: _hole,
                          ),
                        ),
                        for (final d in drivers) _numberAt(context, d, side),
                        Center(
                          child: SizedBox(
                            width: side * _hole * 1.6,
                            child: Text(
                              l.planMapCenter,
                              textAlign: TextAlign.center,
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: 1.3),
                              style: t.titleMedium?.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (c == null) ...[
          const SizedBox(height: LwSpacing.sm),
          Text(
            l.planMapEmpty,
            key: const Key('plan-map-empty'),
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
        const SizedBox(height: LwSpacing.sm),
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            for (final d in drivers)
              _DriverPill(
                driver: d,
                percent: c == null ? null : (c[d.index] * 100).round(),
                colour: c == null
                    ? p.surfaceMuted
                    : segmentColours(p)[d.index % 8],
                onTap: () => onOpen(d),
              ),
          ],
        ),
      ],
    );
  }

  Widget _numberAt(BuildContext context, Driver d, double side) {
    final p = LwPalette.of(context);
    final step = 2 * math.pi / drivers.length;
    final angle = -math.pi / 2 + step * (d.index + 0.5);
    final r = side / 2 * (1 + _hole) / 2;
    const dot = LwSize.minTapTarget * 0.6;
    return Positioned(
      left: side / 2 + r * math.cos(angle) - dot / 2,
      top: side / 2 + r * math.sin(angle) - dot / 2,
      child: Container(
        width: dot,
        height: dot,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
        child: Text(
          '${d.index + 1}',
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: 1.2),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: p.textPrimary),
        ),
      ),
    );
  }
}

class _DriverPill extends StatelessWidget {
  const _DriverPill({
    required this.driver,
    required this.percent,
    required this.colour,
    required this.onTap,
  });

  final Driver driver;
  final int? percent;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final pct = percent;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: pct == null
          ? l.planMapDriverLabelEmpty(driver.label)
          : l.planMapDriverLabel(driver.label, pct),
      child: Material(
        key: Key('plan-driver-${driver.index}'),
        color: colour,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: LwSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${driver.index + 1}',
                    style: t.labelMedium?.copyWith(color: p.primaryDark),
                  ),
                  const SizedBox(width: LwSpacing.xs),
                  Flexible(
                    child: Text(
                      pct == null ? driver.label : '${driver.label} · $pct%',
                      style: t.labelMedium?.copyWith(color: p.onTint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.colours,
    required this.fill,
    required this.deep,
    required this.gap,
    required this.hole,
  });

  final List<Color> colours;
  final List<double>? fill;
  final Color deep;
  final Color gap;
  final double hole;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * hole;
    final n = colours.length;
    final step = 2 * math.pi / n;
    Path wedge(double r, int i) => Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + step * i,
        step,
        false,
      )
      ..close();
    for (var i = 0; i < n; i++) {
      canvas.drawPath(wedge(outer, i), Paint()..color = colours[i]);
      final f = fill;
      if (f != null && i < f.length) {
        // The filled part grows outwards with completion, a deeper shade.
        final r = inner + (outer - inner) * f[i].clamp(0, 1);
        canvas.drawPath(wedge(r, i), Paint()..color = _filled(colours[i]));
      }
    }
    // White gaps between segments and the centre circle.
    final line = Paint()
      ..color = gap
      ..strokeWidth = 3;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + step * i;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * outer, line);
    }
    canvas.drawCircle(c, inner, Paint()..color = gap);
  }

  /// A richer shade of the same pastel: more colour, a little darker in
  /// light mode and lighter in dark mode, so the hue stays recognisable.
  Color _filled(Color c) {
    final hsl = HSLColor.fromColor(c);
    final light = hsl.lightness > 0.5;
    return hsl
        .withSaturation(
          (hsl.saturation + (light ? 0.05 : 0.3)).clamp(0, 1).toDouble(),
        )
        .withLightness(
          (hsl.lightness + (light ? -0.13 : 0.14)).clamp(0, 1).toDouble(),
        )
        .toColor();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.colours != colours || old.fill != fill || old.deep != deep;
}
