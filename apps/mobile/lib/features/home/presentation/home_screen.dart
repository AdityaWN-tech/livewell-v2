import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../dev/application/preview_mode.dart';
import '../../settings/presentation/settings_screen.dart';

/// True when check-ins can be saved: signed in, or the dev preview.
final canCheckInProvider = Provider<bool>(
  (ref) =>
      ref.watch(previewModeProvider) ||
      ref.watch(authServiceProvider).currentUser != null,
);

/// Today's check-in (local date), live. Re-read on resume so the day
/// changes after midnight.
final todayCheckInProvider = StreamProvider<CheckIn?>((ref) {
  if (!ref.watch(canCheckInProvider)) return Stream.value(null);
  final today = localDateKey(ref.watch(clockProvider)());
  return ref.watch(checkInRepositoryProvider).watchDay(today);
});

/// Home tab: the Why, then the daily check-in result (T-DLY-02). At most one
/// primary and two secondary actions (FR-DLY-03). Later it gains the avatar,
/// briefing and real next step (T-DLY-01).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(todayCheckInProvider);
        _maybeAsk();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  String get _today => localDateKey(ref.read(clockProvider)());

  /// First open of the day: ask how they feel before anything else. Once per
  /// day only; closing the sheet counts as asked.
  Future<void> _maybeAsk() async {
    if (_asking || !mounted || !ref.read(canCheckInProvider)) return;
    _asking = true;
    try {
      final today = _today;
      final existing = await ref
          .read(checkInRepositoryProvider)
          .watchDay(today)
          .first;
      final prompts = ref.read(checkInPromptStoreProvider);
      final ask = shouldAskToday(
        today: today,
        hasCheckinToday: existing != null,
        lastAskedDay: await prompts.lastAskedDay(),
      );
      if (!ask || !mounted) return;
      await prompts.markAsked(today);
      if (!mounted) return;
      await _openCheckIn(today);
    } finally {
      _asking = false;
    }
  }

  Future<void> _openCheckIn([String? date]) async {
    // The sheet can open on the first frame, before the profile has
    // loaded; wait briefly for it so the greeting can use the first name.
    final profile =
        ref.read(currentProfileProvider).value ??
        await ref
            .read(currentProfileProvider.future)
            .timeout(const Duration(seconds: 1), onTimeout: () => null);
    if (!mounted) return;
    final firstName = profile?.displayName?.trim().split(' ').first;
    await showCheckInSheet(context, date: date ?? _today, firstName: firstName);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final why = ref.watch(currentProfileProvider).value?.whyStatement;
    final checkIn = ref.watch(todayCheckInProvider).value;
    return LwScreen(
      actions: const [SettingsAction()],
      title: l.tabHome,
      children: [
        // The Why is shown on Home (FR-ONB-05).
        if (why != null && why.isNotEmpty) ...[
          LwCard(eyebrow: l.homeWhyEyebrow, title: why),
          const SizedBox(height: LwSpacing.md),
        ],
        if (checkIn != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LwSpacing.sm),
            child: Text(
              switch (toneFor(checkIn)) {
                CheckInTone.high => l.checkinResponseHigh,
                CheckInTone.steady => l.checkinResponseSteady,
                CheckInTone.gentle => l.checkinResponseGentle,
              },
              key: const Key('checkin-response'),
              style: t.titleLarge,
            ),
          ),
          const SizedBox(height: LwSpacing.sm),
          LwCard(
            key: const Key('today-step'),
            eyebrow: l.homeTodayStepEyebrow,
            title: checkIn.gentleDay
                ? l.homeTodayStepGentle
                : checkIn.timeAvailable != null
                ? l.homeTodayStepTimed(checkIn.timeAvailable!)
                : l.homeTodayStepUntimed,
          ),
        ] else ...[
          if (ref.watch(canCheckInProvider)) ...[
            LwCard(
              key: const Key('home-checkin-card'),
              title: l.homeCheckInTitle,
              body: l.homeCheckInBody,
              onTap: _openCheckIn,
            ),
            const SizedBox(height: LwSpacing.md),
          ],
          LwEmptyState(
            icon: Icons.wb_sunny_outlined,
            title: l.homeEmptyTitle,
            body: l.homeEmptyBody,
          ),
        ],
      ],
    );
  }
}
