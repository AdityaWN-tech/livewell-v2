import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/social_sign_in.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/firebase_auth_service.dart';
import 'auth_copy.dart';

/// Choose how to sign in (FR-ONB-01, D-02). Phone first: most current
/// portal members use +91 phone numbers. Google and Apple are one-tap logo
/// buttons (T-ONB-03a): one tap signs in, or signs up if there's no account.
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
              const SizedBox(height: LwSpacing.xl),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LwSpacing.sm,
                    ),
                    child: Text(l.signInOrContinueWith, style: t.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: LwSpacing.md),
              // Apple is offered wherever Google is (App Store rule 4.8):
              // native on iOS, Firebase's web flow on Android.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SocialSignInButton.google(
                    key: const Key('sign-in-google'),
                    label: l.signInGoogle,
                    onPressed: _busy ? null : () => _provider(false),
                  ),
                  const SizedBox(width: LwSpacing.lg),
                  SocialSignInButton.apple(
                    key: const Key('sign-in-apple'),
                    label: l.signInApple,
                    onPressed: _busy ? null : () => _provider(true),
                  ),
                ],
              ),
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
