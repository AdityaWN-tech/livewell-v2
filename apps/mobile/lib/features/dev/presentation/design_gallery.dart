import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';

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
            Wrap(
              spacing: LwSpacing.xs,
              runSpacing: LwSpacing.xs,
              children: [
                _Swatch('primary', p.primary, p.onPrimary),
                _Swatch('primaryTint', p.primaryTint, p.onPrimaryTint),
                _Swatch('accent', p.accent, p.onAccent),
                _Swatch('accentTint', p.accentTint, p.textPrimary),
                _Swatch('background', p.background, p.textPrimary),
                _Swatch('surface', p.surface, p.textPrimary),
                _Swatch('success', p.success, p.surface),
                _Swatch('caution', p.caution, p.surface),
                _Swatch('emergency', p.emergency, p.onEmergency),
              ],
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
                  ],
                ),
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

const _radii = [LwRadius.smAll, LwRadius.mdAll, LwRadius.lgAll];

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
  const _Swatch(this.name, this.color, this.onColor);
  final String name;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 56,
    padding: const EdgeInsets.all(LwSpacing.xs),
    decoration: BoxDecoration(
      color: color,
      borderRadius: LwRadius.smAll,
      border: Border.all(color: LwPalette.of(context).outlineSoft),
    ),
    child: Text(
      name,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor),
    ),
  );
}
