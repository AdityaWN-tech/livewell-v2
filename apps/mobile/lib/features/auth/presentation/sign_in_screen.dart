import 'package:flutter/material.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';

/// Sign-in entry (FR-ONB-01). Email, phone OTP, Google and Apple arrive in
/// the next step of T-ONB-01.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LwScreen(
      title: l.signInTitle,
      children: [
        LwEmptyState(
          icon: Icons.person_outline,
          title: l.signInTitle,
          body: l.signInComingSoon,
        ),
      ],
    );
  }
}
