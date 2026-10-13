import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/firebase_auth_service.dart';
import 'auth_copy.dart';

/// Choose how to sign in (FR-ONB-01, D-02). Phone first: most current
/// portal members use +91 phone numbers.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _provider(bool apple) async {
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    await runSignIn(
      context,
      ref,
      apple ? auth.signInWithApple : auth.signInWithGoogle,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    // Apple sign-in is offered on iPhone (App Store rule when Google is offered).
    final showApple = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              Text(l.signInTitle, style: t.displaySmall),
              const SizedBox(height: LwSpacing.sm),
              Text(l.signInBody, style: t.bodyMedium),
              const SizedBox(height: LwSpacing.xl),
              FilledButton.icon(
                icon: const Icon(Icons.phone_iphone),
                onPressed: () => context.push('/sign-in/phone'),
                label: Text(l.signInPhone),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.mail_outline),
                onPressed: () => context.push('/sign-in/email'),
                label: Text(l.signInEmail),
              ),
              const SizedBox(height: LwSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => _provider(false),
                label: Text(l.signInGoogle),
              ),
              if (showApple) ...[
                const SizedBox(height: LwSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.apple),
                  onPressed: () => _provider(true),
                  label: Text(l.signInApple),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: LwSpacing.lg),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
