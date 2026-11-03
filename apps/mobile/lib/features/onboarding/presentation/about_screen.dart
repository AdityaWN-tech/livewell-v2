import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_progress.dart';

/// "What Live Well does and does not do" (FR-ONB-02, spec 1.1).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: l.aboutTitle,
      art: 'feature_reflection',
      primaryLabel: l.commonContinue,
      onPrimary: () async {
        await ref.read(onboardingProvider.notifier).goTo(OnboardingStep.age);
        if (context.mounted) context.push(OnboardingStep.age.path);
      },
      children: [
        LwSectionHeader(l.aboutDoesHeader),
        for (final line in [
          l.aboutDoes1,
          l.aboutDoes2,
          l.aboutDoes3,
          l.aboutDoes4,
        ])
          _Point(
            icon: Icons.check_circle_outline,
            color: p.success,
            text: line,
          ),
        LwSectionHeader(l.aboutDoesNotHeader),
        for (final line in [
          l.aboutDoesNot1,
          l.aboutDoesNot2,
          l.aboutDoesNot3,
          l.aboutDoesNot4,
        ])
          _Point(icon: Icons.block, color: p.textSecondary, text: line),
        const SizedBox(height: LwSpacing.md),
        Text(l.aboutEmergency, style: t.bodySmall),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: LwSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: LwSize.iconMd),
        const SizedBox(width: LwSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

/// Shared layout for onboarding steps (illustrated style, T-UI-02i): the
/// soft page wash, optional art, the title in the page (it wraps at large
/// text sizes), scrolling content and one primary button pinned at the
/// bottom (one primary action, spec 4.1).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.footer,
    this.art,
  });

  final String title;
  final List<Widget> children;
  final String primaryLabel;

  /// Null disables the button.
  final VoidCallback? onPrimary;

  /// Optional line above the button (e.g. why it is disabled).
  final Widget? footer;

  /// Optional illustration id (assets/illustrations) above the title.
  final String? art;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    return Scaffold(
      backgroundColor: p.washTop,
      appBar: AppBar(backgroundColor: p.washTop),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.washTop, p.washBottom],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(LwSpacing.screenGutter),
                  children: [
                    if (art != null) ...[
                      Center(child: Illustration(art!, width: 120, height: 96)),
                      const SizedBox(height: LwSpacing.md),
                    ],
                    LwPageTitle(title),
                    ...children,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (footer != null) ...[
                      footer!,
                      const SizedBox(height: LwSpacing.xs),
                    ],
                    FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
