import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart' show whyPath;
import '../../account/data/profile_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../home/application/home_data.dart';
import '../../checkin/presentation/checkin_sheet.dart';
import '../../track/presentation/weekly_wins_screen.dart';
import 'plan_screen.dart' show affirmationFor;

/// MY GOAL DO IT, reached from Plan (FR-GOL-06). One row per letter
/// (spec Appendix B); every letter opens the part of the app that does it
/// (Step 4b, D-54), never a "coming soon".
/// TODO(T-GOL-06): re-house the prototype's own tabs once its code is
/// available (needs-product: the prototype isn't in this repo).
class FrameworkScreen extends ConsumerWidget {
  const FrameworkScreen({super.key});

  /// Mindset: the day's thought, the same one Plan shows.
  Future<void> _thought(BuildContext context, DateTime now) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          key: const Key('framework-thought'),
          padding: const EdgeInsets.fromLTRB(
            LwSpacing.lg,
            0,
            LwSpacing.lg,
            LwSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.frameworkThoughtTitle, style: t.titleLarge),
              const SizedBox(height: LwSpacing.sm),
              Text('“${affirmationFor(l, now)}”', style: t.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }

  /// Accountability: today's check-in, or Track once it's done.
  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    if (ref.read(todayCheckInProvider).value != null) {
      context.go('/track');
      return;
    }
    final now = ref.read(clockProvider)();
    await showCheckInSheet(
      context,
      date: localDateKey(now),
      firstName: ref.read(firstNameProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final why = ref.watch(currentProfileProvider).value?.whyStatement;
    final now = ref.watch(clockProvider)();
    final rows = <(String, String, String, VoidCallback)>[
      (
        'M',
        l.frameworkMindset,
        l.frameworkMindsetBody,
        () => _thought(context, now),
      ),
      (
        'Y',
        l.frameworkWhy,
        (why == null || why.isEmpty) ? l.frameworkWhyEmpty : '“$why”',
        () => context.push('$whyPath?edit=1'),
      ),
      ('G', l.frameworkGoals, l.frameworkGoalsBody, () => context.go('/plan')),
      (
        'O',
        l.frameworkOrganization,
        l.frameworkOrganizationBody,
        () => context.push('/plan/routine'),
      ),
      (
        'A',
        l.frameworkAccountability,
        l.frameworkAccountabilityBody,
        () => _checkIn(context, ref),
      ),
      (
        'L',
        l.frameworkLifestyle,
        l.frameworkLifestyleBody,
        () => context.go('/learn'),
      ),
      (
        'D',
        l.frameworkDiscipline,
        l.frameworkDisciplineBody,
        () => context.go('/plan'),
      ),
      (
        'O',
        l.frameworkOptimism,
        l.frameworkOptimismBody,
        () => context.push(WeeklyWinsScreen.path),
      ),
      (
        'I',
        l.frameworkImplementation,
        l.frameworkImplementationBody,
        () => context.go('/home'),
      ),
      (
        'T',
        l.frameworkTracking,
        l.frameworkTrackingBody,
        () => context.go('/track'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwPageTitle(l.frameworkTitle),
          Text(l.frameworkIntro, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.md),
          for (final (i, (letter, name, body, open)) in rows.indexed) ...[
            _LetterRow(
              key: Key('framework-$i'),
              letter: letter,
              name: name,
              body: body,
              onTap: open,
            ),
            const SizedBox(height: LwSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  const _LetterRow({
    super.key,
    required this.letter,
    required this.name,
    required this.body,
    required this.onTap,
  });

  final String letter;
  final String name;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LwSize.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(LwSpacing.sm),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: LwSize.avatarSm,
                    height: LwSize.avatarSm,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.heroSurface,
                      borderRadius: LwRadius.smAll,
                    ),
                    child: Text(
                      letter,
                      style: t.titleMedium?.copyWith(color: p.onHeroSurface),
                    ),
                  ),
                ),
                const SizedBox(width: LwSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleSmall),
                      Text(body, style: t.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
