import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../domain/focus.dart';
import 'activity_check_screen.dart';

/// content/plan/focus_to_driver.json (copied to assets/plan/).
final focusMapProvider = FutureProvider<FocusMap>(
  (ref) async => FocusMap.parse(
    await rootBundle.loadString(
      'assets/plan/focus_to_driver.json',
      cache: false,
    ),
  ),
);

/// "What would you like to work on this week?" (T-ONB-03d). Pick 1,
/// optionally a 2nd; movement-related choices get the FR-GOL-03 activity
/// check before any plan is made.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  /// In the order picked; the first is the main focus.
  final _picked = <FocusArea>[];
  bool _busy = false;

  void _toggle(FocusArea f) {
    final l = AppLocalizations.of(context);
    setState(() {
      if (_picked.contains(f)) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _picked.remove(f);
      } else if (_picked.length < FocusRules.maxChoices) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _picked.add(f);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.focusFull)));
      }
    });
  }

  Future<void> _continue() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final map = await ref.read(focusMapProvider.future);
      bool? limited;
      if (map.needsActivityCheck(_picked)) {
        if (!mounted) return;
        limited = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ActivityCheckScreen()),
        );
        // Back without answering: stay here, nothing saved.
        if (limited == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
      }
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref
          .read(profileRepositoryProvider)
          .saveFocus(
            uid,
            choices: [for (final f in _picked) f.id],
            driver: map.driverOf(_picked.first),
            activityLimited: limited,
            // TODO(T-ONB-03e): the 7-day starter plan comes next.
            nextStep: ProfileStep.assessment,
          );
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.focusSaveError)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final options = [
      (FocusArea.moveMore, l.focusMoveMore, Icons.directions_walk),
      (FocusArea.sleepBetter, l.focusSleepBetter, Icons.bedtime_outlined),
      (FocusArea.eatBetter, l.focusEatBetter, Icons.restaurant_outlined),
      (FocusArea.lessStress, l.focusLessStress, Icons.spa_outlined),
      (FocusArea.moreEnergy, l.focusMoreEnergy, Icons.bolt_rounded),
      (FocusArea.healthyRoutine, l.focusHealthyRoutine, Icons.event_repeat),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(LwSpacing.screenGutter),
                children: [
                  Semantics(
                    header: true,
                    child: Text(l.focusTitle, style: t.displaySmall),
                  ),
                  const SizedBox(height: LwSpacing.xs),
                  Text(l.focusBody, style: t.bodyMedium),
                  const SizedBox(height: LwSpacing.lg),
                  for (final (area, label, icon) in options) ...[
                    _FocusOption(
                      area: area,
                      label: label,
                      icon: icon,
                      rank: _picked.indexOf(area),
                      onTap: () => _toggle(area),
                    ),
                    const SizedBox(height: LwSpacing.xs),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LwSpacing.screenGutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('focus-continue'),
                  onPressed: _picked.isEmpty || _busy ? null : _continue,
                  child: Text(l.focusContinue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusOption extends StatelessWidget {
  const _FocusOption({
    required this.area,
    required this.label,
    required this.icon,
    required this.rank,
    required this.onTap,
  });

  final FocusArea area;
  final String label;
  final IconData icon;

  /// 0 = first choice, 1 = second, -1 = not picked.
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final picked = rank >= 0;
    return Semantics(
      button: true,
      selected: picked,
      container: true,
      excludeSemantics: true,
      label: switch (rank) {
        0 => l.focusFirstLabel(label),
        1 => l.focusSecondLabel(label),
        _ => label,
      },
      child: Material(
        key: Key('focus-${area.id}'),
        color: picked ? p.primaryTint : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: LwRadius.mdAll,
          side: BorderSide(
            color: picked ? p.primary : p.outlineSoft,
            width: picked ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LwSize.inputHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LwSpacing.md,
                vertical: LwSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, color: picked ? p.onPrimaryTint : p.primary),
                  const SizedBox(width: LwSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: t.titleMedium?.copyWith(
                        color: picked ? p.onPrimaryTint : p.textPrimary,
                      ),
                    ),
                  ),
                  if (picked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LwSpacing.xs,
                        vertical: LwSpacing.xxs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: LwRadius.pillAll,
                      ),
                      child: Text(
                        rank == 0 ? l.focusFirst : l.focusSecond,
                        style: t.labelMedium?.copyWith(color: p.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
