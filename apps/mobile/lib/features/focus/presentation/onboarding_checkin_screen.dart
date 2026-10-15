import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show focusPath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../home/application/home_data.dart';

/// The first mood-first check-in during onboarding (T-ONB-03d), reusing
/// the T-DLY-02 sheet (mood, energy, sleep, stress, time, optional note with
/// the red-flag check). It can be skipped; Home won't ask again today.
class OnboardingCheckInScreen extends ConsumerStatefulWidget {
  const OnboardingCheckInScreen({super.key});

  @override
  ConsumerState<OnboardingCheckInScreen> createState() =>
      _OnboardingCheckInScreenState();
}

class _OnboardingCheckInScreenState
    extends ConsumerState<OnboardingCheckInScreen> {
  bool _busy = false;

  String get _today => localDateKey(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Resumed after checking in today: go straight on.
      final existing = await ref
          .read(checkInRepositoryProvider)
          .watchDay(_today)
          .first;
      if (!mounted) return;
      if (existing != null) {
        await _next();
      } else {
        await _checkIn();
      }
    });
  }

  Future<void> _checkIn() async {
    await showCheckInSheet(
      context,
      date: _today,
      firstName: ref.read(firstNameProvider),
    );
    // Saved or closed, either way move on: the check-in is never required.
    if (mounted) await _next();
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(checkInPromptStoreProvider).markAsked(_today);
    final uid = ref.read(authServiceProvider).currentUser!.uid;
    await ref.read(profileRepositoryProvider).setStep(uid, ProfileStep.focus);
    if (mounted) context.go(focusPath);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          children: [
            Semantics(
              header: true,
              child: Text(l.onbCheckinTitle, style: t.displaySmall),
            ),
            const SizedBox(height: LwSpacing.sm),
            Text(l.onbCheckinBody, style: t.bodyMedium),
            const SizedBox(height: LwSpacing.xl),
            FilledButton(
              key: const Key('onb-checkin-start'),
              onPressed: _busy ? null : _checkIn,
              child: Text(l.onbCheckinStart),
            ),
            const SizedBox(height: LwSpacing.sm),
            Center(
              child: TextButton(
                key: const Key('onb-checkin-skip'),
                onPressed: _busy ? null : _next,
                child: Text(l.onbCheckinSkip),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
