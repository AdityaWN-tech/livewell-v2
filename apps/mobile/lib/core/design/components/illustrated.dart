import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../features/track/domain/track_models.dart';
import '../illustration/illustration.dart';
import '../tokens.dart';

/// Shared illustrated components (T-UI-02i): the pastel cards used on Home,
/// Track and Plan. Built only from tokens; screens pass their own words.

/// A soft pastel card (big radius, no border), the base of the category
/// cards.
class LwPastelCard extends StatelessWidget {
  const LwPastelCard({
    super.key,
    required this.tint,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(LwSpacing.cardPadding),
  });

  final Color tint;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Material(
      color: tint,
      borderRadius: LwRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// A small motion that plays once when it first appears (T-UI-02i): a
/// gentle bounce, or a flicker for the streak flame. Never repeats, and is
/// skipped entirely with reduced motion.
class LwOnceMotion extends StatelessWidget {
  const LwOnceMotion({
    super.key,
    required this.child,
    this.kind = LwMotionKind.bounce,
  });

  final Widget child;
  final LwMotionKind kind;

  @override
  Widget build(BuildContext context) {
    final d = LwMotion.duration(context, const Duration(milliseconds: 900));
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Curves.easeOut,
      child: child,
      builder: (context, v, child) {
        // Fades out as v reaches 1, so it always ends at rest.
        final wave = math.sin(v * math.pi * 3) * (1 - v);
        return switch (kind) {
          LwMotionKind.bounce => Transform.translate(
            offset: Offset(0, -6 * wave),
            child: child,
          ),
          LwMotionKind.flicker => Transform.scale(
            scale: 1 + 0.08 * wave,
            child: child,
          ),
        };
      },
    );
  }
}

enum LwMotionKind { bounce, flicker }

/// A still waveform (decoration; fine with reduced motion).
class LwWaveform extends StatelessWidget {
  const LwWaveform({super.key, this.mirrored = false, this.color});

  final bool mirrored;
  final Color? color;

  static const _heights = <double>[10, 18, 26, 14, 22];

  @override
  Widget build(BuildContext context) {
    final c = color ?? LwPalette.of(context).outlineStrong;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in mirrored ? _heights.reversed : _heights)
            Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: c,
                borderRadius: LwRadius.pillAll,
              ),
            ),
        ],
      ),
    );
  }
}

/// One Quick Check-in tile (Mood, Energy, Sleep, Stress): art, name and
/// today's answer in full words; opens the check-in.
class LwCheckinTile extends StatefulWidget {
  const LwCheckinTile({
    super.key,
    required this.id,
    required this.label,
    required this.art,
    required this.tint,
    required this.value,
    required this.onTap,
  });

  final String id;
  final String label;
  final String art;
  final Color tint;
  final String value;
  final VoidCallback onTap;

  @override
  State<LwCheckinTile> createState() => _LwCheckinTileState();
}

class _LwCheckinTileState extends State<LwCheckinTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final id = widget.id;
    final label = widget.label;
    final art = widget.art;
    final value = widget.value;
    return Semantics(
      button: true,
      label: l.homeTileLabel(label, value),
      container: true,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: LwMotion.duration(context, LwMotion.fast),
        child: Material(
          color: widget.tint,
          borderRadius: LwRadius.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('home-tile-$id'),
            onTap: widget.onTap,
            onHighlightChanged: (on) => setState(() => _pressed = on),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LwSpacing.xs,
                  vertical: LwSpacing.sm,
                ),
                child: Column(
                  children: [
                    Illustration(art, width: 40, height: 40),
                    const SizedBox(height: LwSpacing.xxs),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: t.labelMedium?.copyWith(color: p.onTint),
                    ),
                    Text(
                      value,
                      key: Key('home-tile-$id-value'),
                      textAlign: TextAlign.center,
                      style: t.labelSmall?.copyWith(color: p.onTintSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// N Day Streak (T-UI-02c). Grace and restart wording only: no red, no
/// alarm for missed days (FR-DLY-07).
class LwStreakCard extends StatelessWidget {
  const LwStreakCard(this.streak, {super.key});
  final StreakSummary? streak;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final s = streak;
    return Container(
      key: const Key('home-streak'),
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      decoration: BoxDecoration(color: p.butter, borderRadius: LwRadius.lgAll),
      child: Row(
        children: [
          const LwOnceMotion(
            kind: LwMotionKind.flicker,
            child: Illustration('icon_streak', width: 48, height: 48),
          ),
          const SizedBox(width: LwSpacing.sm),
          Expanded(
            child: s == null || s.length == 0
                ? Text(
                    l.homeStreakEmpty,
                    style: t.bodyMedium?.copyWith(color: p.onTint),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeStreakTitle(s.length),
                        style: t.titleMedium?.copyWith(color: p.onTint),
                      ),
                      Text(
                        l.homeStreakKeepGoing,
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                    ],
                  ),
          ),
          const Illustration('lesson_driver_1', width: 40, height: 40),
        ],
      ),
    );
  }
}

/// What a Track metric card shows.
class LwMetric {
  const LwMetric({
    required this.id,
    required this.name,
    required this.art,
    required this.tint,
    required this.value,
    required this.detail,
    required this.bars,
    this.label,
    this.onTap,
  });

  final String id;
  final String name;
  final String art;
  final Color tint;
  final String value;
  final String detail;

  /// 0..1, oldest first.
  final List<double> bars;
  final String? label;
  final VoidCallback? onTap;
}

/// A Track metric card: pastel tint, art, value, a kind word and 7 slim
/// mini bars.
class LwMetricCard extends StatelessWidget {
  const LwMetricCard(this.m, {super.key});
  final LwMetric m;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final body = Padding(
      padding: const EdgeInsets.all(LwSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Illustration(m.art, width: 32, height: 32),
              const SizedBox(width: LwSpacing.xs),
              Expanded(
                child: Text(
                  m.name,
                  style: t.titleSmall?.copyWith(color: p.onTint),
                ),
              ),
            ],
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(
            m.value,
            key: Key('track-${m.id}-value'),
            style: t.titleLarge?.copyWith(color: p.onTint),
          ),
          if (m.detail.isNotEmpty)
            Text(
              m.detail,
              key: Key('track-${m.id}-detail'),
              style: t.bodySmall?.copyWith(color: p.onTintSecondary),
            ),
          if (m.bars.isNotEmpty) ...[
            const SizedBox(height: LwSpacing.sm),
            LwMiniBars(m.bars, colour: LwPalette.richer(m.tint)),
          ],
        ],
      ),
    );
    return Semantics(
      button: m.onTap != null,
      container: true,
      excludeSemantics: true,
      label: m.label ?? l.trackCardLabel(m.name, m.value, m.detail).trim(),
      child: Material(
        key: Key('track-card-${m.id}'),
        color: m.tint,
        borderRadius: LwRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: m.onTap == null ? body : InkWell(onTap: m.onTap, child: body),
      ),
    );
  }
}

/// Small rounded bars, oldest first (decoration: the card's label says the
/// value).
class LwMiniBars extends StatelessWidget {
  const LwMiniBars(this.values, {super.key, required this.colour});

  final List<double> values;
  final Color colour;

  /// Always 7 slim slots, newest on the right, as in the design.
  static const slots = 7;

  @override
  Widget build(BuildContext context) {
    final padded = [
      for (var i = values.length; i < slots; i++) null,
      ...values.length > slots ? values.sublist(values.length - slots) : values,
    ];
    return SizedBox(
      height: LwSpacing.xl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in padded)
            Expanded(
              child: v == null
                  ? const SizedBox()
                  : FractionallySizedBox(
                      heightFactor: v.clamp(0.08, 1).toDouble(),
                      widthFactor: 0.6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colour,
                          borderRadius: LwRadius.smAll,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
