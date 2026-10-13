import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// First screen for new users (spec 5.2 step 1). The onboarding flow behind
/// "Get started" comes in T-ONB-01; the buttons are placeholders until then.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
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
                onPressed: () {},
                child: Text(l10n.welcomeGetStarted),
              ),
              const SizedBox(height: LwSpacing.xs),
              TextButton(
                onPressed: () {},
                child: Text(l10n.welcomeHaveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
