import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth.dart';
import 'auth_copy.dart';

/// Phone sign-in with a one-time SMS code (D-02). Two stages: number, then
/// code. "Resend" unlocks after [resendDelay].
class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  static const resendDelay = Duration(seconds: 30);

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _numberForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _code = TextEditingController();
  late PhoneCountry _country =
      PlatformDispatcher.instance.locale.countryCode == 'US'
      ? PhoneCountry.us
      : PhoneCountry.india;
  PhoneVerification? _verification;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _number.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = PhoneSignInScreen.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_numberForm.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final e164 = _country.toE164(_number.text)!;
    setState(() => _busy = true);
    try {
      final v = await ref
          .read(authServiceProvider)
          .startPhoneSignIn(
            e164,
            resendToken: resend ? _verification?.resendToken : null,
          );
      if (!mounted) return;
      setState(() => _verification = v);
      _startResendTimer();
    } on AuthException catch (e) {
      if (mounted) showAuthMessage(context, authErrorText(l, e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (!_codeForm.currentState!.validate()) return;
    setState(() => _busy = true);
    final v = _verification!;
    await runSignIn(
      context,
      ref,
      () => ref.read(authServiceProvider).confirmPhoneCode(v, _code.text),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = _verification;
    return Scaffold(
      appBar: AppBar(title: Text(v == null ? l.phoneTitle : l.codeTitle)),
      body: SafeArea(
        top: false,
        child: v == null ? _numberStage(l) : _codeStage(l, v),
      ),
    );
  }

  Widget _numberStage(AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _numberForm,
      child: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.phoneCountryLabel, style: t.labelMedium),
          const SizedBox(height: LwSpacing.xs),
          SegmentedButton<PhoneCountry>(
            segments: [
              ButtonSegment(
                value: PhoneCountry.india,
                label: Text(l.countryIndia),
              ),
              ButtonSegment(value: PhoneCountry.us, label: Text(l.countryUs)),
            ],
            selected: {_country},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _country = s.first),
          ),
          const SizedBox(height: LwSpacing.lg),
          TextFormField(
            key: const Key('phone'),
            controller: _number,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-()]')),
            ],
            onFieldSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              labelText: l.phoneNumberLabel,
              prefixText: '${_country.dialCode} ',
            ),
            validator: (value) =>
                _country.toE164(value ?? '') == null ? l.phoneInvalidMsg : null,
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(l.phoneSmsNote, style: t.bodySmall),
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: _busy ? const _Spinner() : Text(l.phoneSendCode),
          ),
        ],
      ),
    );
  }

  Widget _codeStage(AppLocalizations l, PhoneVerification v) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _codeForm,
      child: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.codeBody(v.phoneNumber), style: t.bodyMedium),
          const SizedBox(height: LwSpacing.lg),
          TextFormField(
            key: const Key('code'),
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onFieldSubmitted: (_) => _verify(),
            decoration: InputDecoration(labelText: l.codeLabel),
            validator: (value) =>
                (value ?? '').length == 6 ? null : l.codeInvalidMsg,
          ),
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy ? const _Spinner() : Text(l.codeVerify),
          ),
          const SizedBox(height: LwSpacing.xs),
          TextButton(
            onPressed: _busy || _resendIn > 0
                ? null
                : () => _sendCode(resend: true),
            child: Text(
              _resendIn > 0 ? l.codeResendIn(_resendIn) : l.codeResend,
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _timer?.cancel();
                    _verification = null;
                    _code.clear();
                  }),
            child: Text(l.codeChangeNumber),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: LwSize.iconSm,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
