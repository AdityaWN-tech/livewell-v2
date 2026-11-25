import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/firebase_auth_service.dart';
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
        child: _FillOrScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(l.ageTitle, style: t.displaySmall),
              ),
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
                  // Under 18: forget everything collected so far, including
                  // a sign-in account made before this check (FR-ONB-04).
                  final auth = ref.read(authServiceProvider);
                  if (auth.currentUser != null) {
                    try {
                      await auth.deleteCurrentUser();
                    } catch (_) {
                      await auth.signOut();
                      ref.read(signedInUidProvider.notifier).refresh();
                    }
                  }
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
        child: _FillOrScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Semantics(
                header: true,
                child: Text(l.under18Title, style: t.displaySmall),
              ),
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

/// Fills the screen (so the Spacers push the buttons down) and scrolls when
/// large text makes the content taller than the screen (T-REL-01).
class _FillOrScroll extends StatelessWidget {
  const _FillOrScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: const EdgeInsets.all(LwSpacing.screenGutter),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: box.maxHeight - LwSpacing.screenGutter * 2,
        ),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}
