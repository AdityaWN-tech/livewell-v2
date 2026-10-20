import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth.dart';
import 'auth_copy.dart';

/// Email and password: sign in, create an account, or reset the password.
class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _showPassword = false;
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    await runSignIn(
      context,
      ref,
      () => _create
          ? auth.createAccountWithEmail(_email.text, _password.text)
          : auth.signInWithEmail(_email.text, _password.text),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      showAuthMessage(context, l.emailInvalidMsg);
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) showAuthMessage(context, l.resetSent(email));
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, authErrorText(l, e.failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(LwSpacing.screenGutter),
            children: [
              LwPageTitle(l.emailTitle),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.emailModeSignIn)),
                  ButtonSegment(value: true, label: Text(l.emailModeCreate)),
                ],
                selected: {_create},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _create = v.first),
              ),
              const SizedBox(height: LwSpacing.lg),
              TextFormField(
                key: const Key('email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.emailLabel),
                validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                    ? null
                    : l.emailInvalidMsg,
              ),
              const SizedBox(height: LwSpacing.md),
              TextFormField(
                key: const Key('password'),
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: [
                  _create ? AutofillHints.newPassword : AutofillHints.password,
                ],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l.passwordLabel,
                  helperText: _create ? l.passwordHint : null,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? l.passwordHide : l.passwordShow,
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').length >= 8 ? null : l.passwordShortMsg,
              ),
              const SizedBox(height: LwSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: LwSize.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_create ? l.emailModeCreate : l.emailModeSignIn),
              ),
              if (!_create)
                TextButton(
                  onPressed: _busy ? null : _reset,
                  child: Text(l.forgotPassword),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
