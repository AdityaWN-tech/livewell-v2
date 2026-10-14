import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/flavor.dart';
import '../../../core/design/tokens.dart';
import '../../dev/application/preview_mode.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/domain/onboarding_progress.dart';
import '../../../l10n/app_localizations.dart';

/// First screen for new users (spec 5.2 step 1). "Get started" begins
/// onboarding; "I already have an account" goes straight to sign-in.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDev = ref.watch(flavorProvider) == Flavor.dev;
    final t = Theme.of(context).textTheme;
    // No app bar here, so set the status bar icons explicitly; otherwise the
    // splash's light (white) icons carry over onto this light screen.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: ClipRRect(
                    borderRadius: LwRadius.lgAll,
                    child: Image.asset(
                      'assets/brand/logo.png',
                      width: LwSize.splashMark,
                      semanticLabel: l10n.appTitle,
                    ),
                  ),
                ),
                const SizedBox(height: LwSpacing.xl),
                Text(
                  l10n.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: t.displaySmall,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(onboardingProvider.notifier)
                        .goTo(OnboardingStep.about);
                    if (context.mounted) {
                      context.push(OnboardingStep.about.path);
                    }
                  },
                  child: Text(l10n.welcomeGetStarted),
                ),
                const SizedBox(height: LwSpacing.xs),
                TextButton(
                  onPressed: () => context.push(OnboardingStep.signIn.path),
                  child: Text(l10n.welcomeHaveAccount),
                ),
                if (isDev)
                  TextButton(
                    onPressed: () {
                      ref.read(previewModeProvider.notifier).enable();
                      context.go('/home');
                    },
                    child: Text(l10n.devPreviewApp),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
