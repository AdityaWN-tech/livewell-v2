import 'package:flutter/material.dart';

import '../../../core/design/components/illustrated.dart';
import '../../../core/design/components/lw_components.dart';
import '../../../core/design/components/speech_bubble.dart';
import '../../../core/design/tokens.dart';
import '../../track/domain/track_models.dart';

/// Dev-flavor screen showing every design token, for review on a real device.
/// Not reachable in staging or prod.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Design tokens')),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: LwRadius.lgAll,
              child: Image.asset(
                'assets/brand/logo.png',
                width: 160,
                semanticLabel: 'Live Well logo',
              ),
            ),
          ),
          const SizedBox(height: LwSpacing.sectionGap),
          _Section('Colours', [
            Column(
              children: [
                _Swatch('primary', p.primary),
                _Swatch('primaryDark', p.primaryDark),
                _Swatch('primaryTint', p.primaryTint),
                _Swatch('accent (charts only)', p.accent),
                _Swatch('accentStrong', p.accentStrong),
                _Swatch('heroSurface', p.heroSurface),
                _Swatch('background', p.background),
                _Swatch('surface', p.surface),
                _Swatch('surfaceMuted', p.surfaceMuted),
                _Swatch('textPrimary', p.textPrimary),
                _Swatch('textSecondary', p.textSecondary),
                _Swatch('outlineStrong', p.outlineStrong),
                _Swatch('success', p.success),
                _Swatch('caution', p.caution),
                _Swatch('emergency', p.emergency),
              ],
            ),
          ]),
          _Section('Pastel tints', [
            Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                for (final (name, c) in [
                  ('mint', p.mint),
                  ('lime', p.lime),
                  ('lavender', p.lavender),
                  ('peach', p.peach),
                  ('sky', p.sky),
                  ('butter', p.butter),
                  ('rose', p.rose),
                ])
                  _TintCard(name, c),
              ],
            ),
            const SizedBox(height: LwSpacing.xs),
            Container(
              height: LwSize.minTapTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: LwRadius.lgAll,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.washTop, p.washBottom],
                ),
              ),
              child: Text('Page wash', style: t.labelMedium),
            ),
          ]),
          _Section('Type', [
            Text('Login to LIVE WELL', style: t.displaySmall),
            Text('Courses', style: t.headlineSmall),
            Text('Card title', style: t.titleLarge),
            Text(
              'Your 10-minute walk is ready when you are.',
              style: t.bodyLarge,
            ),
            Text(
              'Welcome back! Please enter your details.',
              style: t.bodyMedium,
            ),
            Text('8 sections · 50 lectures', style: t.labelSmall),
          ]),
          _Section('Components', [
            FilledButton(
              onPressed: () {},
              child: const Text('Start 10-min walk'),
            ),
            const SizedBox(height: LwSpacing.sm),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Make it 5 minutes'),
            ),
            const SizedBox(height: LwSpacing.sm),
            const TextField(
              decoration: InputDecoration(hintText: 'Enter your phone'),
            ),
            const SizedBox(height: LwSpacing.sm),
            Wrap(
              spacing: LwSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('In progress'),
                  selected: false,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: LwSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Week')),
                ButtonSegment(value: 1, label: Text('Month')),
              ],
              selected: const {0},
              showSelectedIcon: false,
              onSelectionChanged: (_) {},
            ),
            const SizedBox(height: LwSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(LwSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FROM THE LIVE WELL PORTAL', style: t.labelSmall),
                    const SizedBox(height: LwSpacing.xxs),
                    Text('Steadier blood sugar', style: t.titleLarge),
                    const SizedBox(height: LwSpacing.xxs),
                    Text('Dr Murthy Gokula', style: t.bodySmall),
                    const SizedBox(height: LwSpacing.sm),
                    ClipRRect(
                      borderRadius: LwRadius.pillAll,
                      child: LinearProgressIndicator(
                        value: 0.6,
                        minHeight: LwSpacing.xs,
                        color: p.accent,
                        backgroundColor: p.surfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
            Container(
              padding: const EdgeInsets.all(LwSpacing.cardPadding),
              decoration: BoxDecoration(
                color: p.heroSurface,
                borderRadius: LwRadius.lgAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S NEXT STEP",
                    style: t.labelSmall?.copyWith(
                      color: p.onHeroSurfaceSecondary,
                    ),
                  ),
                  const SizedBox(height: LwSpacing.xxs),
                  Text(
                    '10-min walk after lunch',
                    style: t.titleLarge?.copyWith(color: p.onHeroSurface),
                  ),
                  const SizedBox(height: LwSpacing.sm),
                  FilledButton(onPressed: () {}, child: const Text('Done')),
                ],
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
            Container(
              padding: const EdgeInsets.all(LwSpacing.cardPadding),
              decoration: BoxDecoration(
                color: p.emergency,
                borderRadius: LwRadius.mdAll,
              ),
              child: Text(
                'Emergency card (safety only)',
                style: t.titleMedium?.copyWith(color: p.onEmergency),
              ),
            ),
          ]),
          // The shared illustrated components (T-UI-02i).
          _Section('Illustrated components', [
            LwSectionHeader(
              'Section header',
              actionLabel: 'See all',
              onAction: () {},
            ),
            const SpeechBubble(text: 'A speech bubble from the coach.'),
            const SizedBox(height: LwSpacing.sm),
            LwPastelCard(
              tint: p.lavender,
              child: Text(
                'Pastel card',
                style: t.titleSmall?.copyWith(color: p.onTint),
              ),
            ),
            const SizedBox(height: LwSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: LwCheckinTile(
                    id: 'gallery-mood',
                    label: 'Mood',
                    art: 'icon_mood',
                    tint: p.butter,
                    value: 'Very good',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: LwSpacing.xs),
                Expanded(
                  child: LwMetricCard(
                    LwMetric(
                      id: 'gallery-stress',
                      name: 'Stress',
                      art: 'icon_stress',
                      tint: p.sky,
                      value: '2.5 / 5',
                      detail: 'Moderate',
                      bars: const [0.4, 0.6, 0.4, 0.8, 0.6],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LwSpacing.sm),
            const LwStreakCard(StreakSummary(length: 7, best: 7, week: [])),
            const SizedBox(height: LwSpacing.sm),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [LwWaveform(), LwWaveform(mirrored: true)],
              ),
            ),
          ]),
          _Section('Spacing and radius', [
            for (final (name, size) in _spacings)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: LwSpacing.xxl,
                      child: Text(name, style: t.labelSmall),
                    ),
                    Container(
                      width: size,
                      height: LwSpacing.sm,
                      color: p.accent,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: LwSpacing.xs),
            Row(
              children: [
                for (final radius in _radii)
                  Padding(
                    padding: const EdgeInsets.only(right: LwSpacing.xs),
                    child: Container(
                      width: LwSize.minTapTarget,
                      height: LwSize.minTapTarget,
                      decoration: BoxDecoration(
                        color: p.primaryTint,
                        borderRadius: radius,
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}

const _spacings = [
  ('xxs', LwSpacing.xxs),
  ('xs', LwSpacing.xs),
  ('sm', LwSpacing.sm),
  ('md', LwSpacing.md),
  ('lg', LwSpacing.lg),
  ('xl', LwSpacing.xl),
];

const _radii = [
  LwRadius.smAll,
  LwRadius.mdAll, // buttons
  LwRadius.lgAll, // cards
  LwRadius.pillAll, // chips
];

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LwSpacing.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: LwSpacing.xs),
        ...children,
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: LwSpacing.xs),
      child: Row(
        children: [
          Container(
            width: LwSize.minTapTarget * 2,
            height: LwSize.minTapTarget,
            decoration: BoxDecoration(
              color: color,
              borderRadius: LwRadius.smAll,
              border: Border.all(color: LwPalette.of(context).outlineStrong),
            ),
          ),
          const SizedBox(width: LwSpacing.sm),
          Expanded(child: Text('$name · #$hex', style: t.bodySmall)),
        ],
      ),
    );
  }
}

/// A pastel category card, as on Home and Track.
class _TintCard extends StatelessWidget {
  const _TintCard(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return Container(
      width: 104,
      padding: const EdgeInsets.all(LwSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: LwRadius.lgAll,
        boxShadow: LwShadow.of(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: t.titleSmall?.copyWith(color: p.onTint)),
          Text(
            '#$hex',
            style: t.labelSmall?.copyWith(color: p.onTintSecondary),
          ),
        ],
      ),
    );
  }
}
