import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/profile_repository.dart';

/// MY GOAL DO IT, reached from Plan (FR-GOL-06). One row per letter
/// (spec Appendix B). Parts that exist open; the rest say "Coming soon".
/// TODO(T-GOL-06): re-house the prototype's tabs here once its code is
/// available (needs-product: the prototype isn't in this repo).
class FrameworkScreen extends ConsumerWidget {
  const FrameworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final why = ref.watch(currentProfileProvider).value?.whyStatement;
    final rows = <(String, String, String, String?)>[
      ('M', l.frameworkMindset, l.frameworkMindsetBody, null),
      (
        'Y',
        l.frameworkWhy,
        (why == null || why.isEmpty) ? l.frameworkWhyEmpty : '“$why”',
        null,
      ),
      ('G', l.frameworkGoals, l.frameworkGoalsBody, null),
      ('O', l.frameworkOrganization, l.frameworkOrganizationBody, null),
      ('A', l.frameworkAccountability, l.frameworkAccountabilityBody, null),
      ('L', l.frameworkLifestyle, l.frameworkLifestyleBody, null),
      ('D', l.frameworkDiscipline, l.frameworkDisciplineBody, null),
      ('O', l.frameworkOptimism, l.frameworkOptimismBody, null),
      ('I', l.frameworkImplementation, l.frameworkImplementationBody, null),
      ('T', l.frameworkTracking, l.frameworkTrackingBody, '/track'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.frameworkTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(l.frameworkIntro, style: t.bodyMedium),
          const SizedBox(height: LwSpacing.md),
          for (final (i, (letter, name, body, target)) in rows.indexed) ...[
            _LetterRow(
              key: Key('framework-$i'),
              letter: letter,
              name: name,
              body: body,
              // "Your Why" shows the person's own Why inline.
              available: i == 1 && why != null && why.isNotEmpty,
              onTap: target == null ? null : () => context.go(target),
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
    required this.available,
    this.onTap,
  });

  final String letter;
  final String name;
  final String body;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final soon = onTap == null && !available;
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
                      if (soon)
                        Text(
                          l.frameworkSoon,
                          style: t.labelSmall?.copyWith(color: p.accentStrong),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: p.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
