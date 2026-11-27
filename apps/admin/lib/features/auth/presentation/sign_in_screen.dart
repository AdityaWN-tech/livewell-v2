import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';

/// Staff sign-in. Accounts are made by the owner; there is no sign-up.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on SignInFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
    } on SignInFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LwSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdminLayout.narrowPageWidth,
            ),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Live Well Admin', style: t.displaySmall),
                    ),
                    const SizedBox(height: LwSpacing.xs),
                    Text(
                      'Staff sign-in. Accounts are set up by the owner.',
                      style: t.bodyMedium,
                    ),
                    const SizedBox(height: LwSpacing.lg),
                    TextFormField(
                      key: const Key('sign-in-email'),
                      controller: _email,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v ?? '').trim().contains('@')
                          ? null
                          : 'Enter your work email.',
                    ),
                    const SizedBox(height: LwSpacing.md),
                    TextFormField(
                      key: const Key('sign-in-password'),
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Enter your password.' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: LwSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          key: const Key('sign-in-error'),
                          style: t.bodySmall?.copyWith(color: p.emergency),
                        ),
                      ),
                    ],
                    const SizedBox(height: LwSpacing.lg),
                    FilledButton(
                      key: const Key('sign-in-submit'),
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                    const SizedBox(height: LwSpacing.sm),
                    // Staff and Superadmins sign in with Google (D-112).
                    OutlinedButton(
                      key: const Key('sign-in-google'),
                      onPressed: _busy ? null : _google,
                      child: const Text('Continue with Google'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
