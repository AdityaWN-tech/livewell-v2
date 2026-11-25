import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/plan_models.dart';

/// The Live Well Map (T-UI-02d; colourful petals, T-UI-04): 8 driver petals
/// around a white "Live Well" centre. Each petal shows the driver's number
/// and label (from [Driver]: never invented here) and is its own labelled
/// button. With the 30-day completion (FR-GAM-02) a deeper shade fills each
/// petal outwards. At very large text sizes a row of driver chips follows,
/// so every name can be read at full size.
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

  /// The petal colours, clockwise from the top (owner's reference: mint,
  /// peach, lavender, pink, sky, yellow, ...). Never colour alone: each
  /// petal also has its number and label.
  static List<Color> segmentColours(LwPalette p) => [
    p.mint,
    p.peach,
    p.lavender,
    p.rose,
    p.sky,
    p.butter,
    p.lime,
    p.accentTint,
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

  static const _hole = 0.3;

  /// The wheel's largest size: room for every petal's label.
  static const double maxSide = 320;

  /// Petal labels stop growing here; above it the chips below repeat them.
  static const double labelMaxScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final c = completion;
    final colours = segmentColours(p);
    final bigText = MediaQuery.textScalerOf(context).scale(1) > labelMaxScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, maxSide);
            final size = Size.square(side);
            return Center(
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
                      ExcludeSemantics(
                        child: CustomPaint(
                          size: size,
                          painter: _PetalPainter(
                            colours: [
                              for (var i = 0; i < drivers.length; i++)
                                colours[i % colours.length],
                            ],
                            fill: c,
                            gap: p.surface,
                            hole: _hole,
                            shadow: LwShadow.of(context).first.color,
                          ),
                        ),
                      ),
                      for (final d in drivers) _petalLabel(context, d, side, c),
                      Center(child: _Centre(side: side * _hole)),
                    ],
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
        if (bigText) ...[
          const SizedBox(height: LwSpacing.sm),
          Wrap(
            key: const Key('plan-map-chips'),
            spacing: LwSpacing.xs,
            runSpacing: LwSpacing.xs,
            children: [
              for (final d in drivers)
                _DriverChip(
                  driver: d,
                  percent: c == null ? null : (c[d.index] * 100).round(),
                  colour: colours[d.index % colours.length],
                  onTap: () => onOpen(d),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// The number and label in the middle of a petal: the petal's button.
  Widget _petalLabel(
    BuildContext context,
    Driver d,
    double side,
    List<double>? c,
  ) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final step = 2 * math.pi / drivers.length;
    final angle = -math.pi / 2 + step * (d.index + 0.5);
    final r = side / 2 * (1 + _hole) / 2;
    // Room for the label: the petal's width at its middle, less a margin.
    final w = math.max(
      LwSize.minTapTarget,
      math.min(side * 0.3, 2 * r * math.sin(step / 2) - LwSpacing.xs),
    );
    const h = LwSize.minTapTarget * 1.3;
    final pct = c == null ? null : (c[d.index] * 100).round();
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: labelMaxScale);
    return Positioned(
      left: side / 2 + r * math.cos(angle) - w / 2,
      top: side / 2 + r * math.sin(angle) - h / 2,
      width: w,
      height: h,
      child: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: pct == null
            ? l.planMapDriverLabelEmpty(d.label)
            : l.planMapDriverLabel(d.label, pct),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('plan-driver-${d.index}'),
            customBorder: RoundedRectangleBorder(borderRadius: LwRadius.mdAll),
            onTap: () => onOpen(d),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d.index + 1}',
                    textScaler: scaler,
                    style: t.labelLarge?.copyWith(
                      color: p.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    d.label,
                    textAlign: TextAlign.center,
                    textScaler: scaler,
                    style: t.labelMedium?.copyWith(
                      color: p.onTint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (pct != null)
                    Text(
                      '$pct%',
                      textScaler: scaler,
                      style: t.labelSmall?.copyWith(color: p.onTintSecondary),
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

/// The white centre: a leaf and "Live Well".
class _Centre extends StatelessWidget {
  const _Centre({required this.side});
  final double side;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        padding: const EdgeInsets.all(LwSpacing.xs),
        decoration: BoxDecoration(
          color: p.surface,
          shape: BoxShape.circle,
          boxShadow: LwShadow.of(context),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_outlined, color: p.primary, size: LwSize.iconMd),
              Text(
                l.planMapCenter,
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.3),
                style: t.titleMedium?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A driver as a chip, for very large text sizes.
class _DriverChip extends StatelessWidget {
  const _DriverChip({
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
    final pct = percent;
    return ExcludeSemantics(
      // The petal above is the button for screen readers; this is for sight.
      child: Material(
        key: Key('plan-driver-chip-${driver.index}'),
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

/// Eight rounded petals with white gaps; a deeper shade grows outwards
/// with each driver's completion.
class _PetalPainter extends CustomPainter {
  _PetalPainter({
    required this.colours,
    required this.fill,
    required this.gap,
    required this.hole,
    required this.shadow,
  });

  final List<Color> colours;
  final List<double>? fill;
  final Color gap;
  final double hole;
  final Color shadow;

  /// Rounded corners: the petal is stroked with this width in its own
  /// colour, which rounds its corners by half of it.
  static const double _round = 14;

  /// The white gap between petals, in pixels at the petal's middle.
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - _round / 2;
    final inner = size.shortestSide / 2 * hole;
    final n = colours.length;
    final step = 2 * math.pi / n;
    final mid = (inner + outer) / 2;
    final trim = (_gap + _round) / 2 / mid;

    Path petal(double r, int i) {
      final start = -math.pi / 2 + step * i + trim;
      final sweep = step - 2 * trim;
      final innerTrim = math.min(trim * mid / inner, sweep / 2 * 0.9);
      return Path()
        ..arcTo(
          Rect.fromCircle(center: c, radius: inner),
          start + innerTrim,
          sweep - 2 * innerTrim,
          true,
        )
        ..arcTo(
          Rect.fromCircle(center: c, radius: r),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
    }

    for (var i = 0; i < n; i++) {
      final path = petal(outer, i);
      canvas.drawShadow(path, shadow, 2, false);
      final paint = Paint()
        ..color = colours[i]
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _round;
      canvas
        ..drawPath(path, paint..style = PaintingStyle.fill)
        ..drawPath(path, paint..style = PaintingStyle.stroke);
      final f = fill;
      if (f != null && i < f.length && f[i] > 0) {
        final r = inner + (outer - inner) * f[i].clamp(0, 1);
        final deep = Paint()
          ..color = LwPalette.richer(colours[i])
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = _round;
        final part = petal(r, i);
        canvas
          ..drawPath(part, deep..style = PaintingStyle.fill)
          ..drawPath(part, deep..style = PaintingStyle.stroke);
      }
    }
    canvas.drawCircle(c, inner - _gap / 2, Paint()..color = gap);
  }

  @override
  bool shouldRepaint(_PetalPainter old) =>
      old.colours != colours || old.fill != fill || old.gap != gap;
}
