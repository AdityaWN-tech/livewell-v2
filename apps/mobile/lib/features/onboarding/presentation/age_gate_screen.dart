import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/onboarding_store.dart';
import '../domain/onboarding_progress.dart';

/// 18+ age gate (FR-ONB-04). Comes before sign-in so nothing is stored for
/// under-18s (D-19).
class AgeGateScreen extends ConsumerWidget {
  const AgeGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.ageTitle, style: t.displaySmall),
              const SizedBox(height: LwSpacing.sm),
              Text(l.ageBody, style: t.bodyMedium),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(onboardingProvider.notifier)
                      .confirmAdult(DateTime.now());
                  if (context.mounted) context.push(OnboardingStep.legal.path);
                },
                child: Text(l.ageYes),
              ),
              const SizedBox(height: LwSpacing.xs),
              OutlinedButton(
                onPressed: () async {
                  // Under 18: forget everything collected so far.
                  await ref.read(onboardingProvider.notifier).finish();
                  if (context.mounted) context.go('/onboarding/under-18');
                },
                child: Text(l.ageNo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly stop for under-18s. Nothing has been saved.
class Under18Screen extends StatelessWidget {
  const Under18Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(l.under18Title, style: t.displaySmall),
              const SizedBox(height: LwSpacing.sm),
              Text(l.under18Body, style: t.bodyLarge),
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.go(OnboardingStep.welcome.path),
                child: Text(l.under18Back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
