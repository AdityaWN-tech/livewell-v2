import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';
import '../../consent/presentation/consent_copy.dart';
import '../../dev/application/preview_mode.dart';
import '../data/memory_repository.dart';
import '../domain/memory_fact.dart';

/// "What my coach remembers" (FR-CNV-05; T-AGT-05b, D-101). The two memory
/// consents, the coach's suggestions to keep, and what is remembered. The
/// person decides: keep or delete; delete is final. Nothing here goes to
/// analytics or logs.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  static const path = '/settings/memory';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final consents = ref.watch(currentConsentsProvider);
    final facts = ref.watch(memoryFactsProvider);
    return LwScreen(
      title: l.memoryTitle,
      children: switch ((consents, facts)) {
        (AsyncData(value: final c), AsyncData(value: final f)) => _content(
          context,
          ref,
          l,
          memoryOn: isGranted(c, ConsentType.memory),
          sensitiveOn:
              isGranted(c, ConsentType.memory) &&
              isGranted(c, ConsentType.memorySensitive),
          facts: f,
        ),
        (AsyncError(), _) || (_, AsyncError()) => [Text(l.memoryLoadError)],
        _ => const [Center(child: CircularProgressIndicator())],
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l, {
    required bool memoryOn,
    required bool sensitiveOn,
    required List<MemoryFact> facts,
  }) {
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final proposed = facts.where((f) => f.status == MemoryStatus.proposed);
    final saved = facts.where((f) => f.status == MemoryStatus.saved);
    return [
      Text(l.memoryIntro, style: t.bodyMedium),
      if (ref.watch(previewModeProvider)) ...[
        const SizedBox(height: LwSpacing.xs),
        Text(
          l.devPreviewNotSaved,
          style: t.labelSmall?.copyWith(color: p.caution),
        ),
      ],
      const SizedBox(height: LwSpacing.sm),
      _ConsentSwitch(
        key: const Key('memory-consent'),
        type: ConsentType.memory,
        value: memoryOn,
        enabled: true,
      ),
      _ConsentSwitch(
        key: const Key('memory-sensitive-consent'),
        type: ConsentType.memorySensitive,
        value: sensitiveOn,
        // Health details only together with memory itself.
        enabled: memoryOn,
      ),
      if (!memoryOn && facts.isNotEmpty) ...[
        const SizedBox(height: LwSpacing.xs),
        Text(
          l.memoryOffNote,
          key: const Key('memory-off-note'),
          style: t.bodySmall?.copyWith(color: p.textSecondary),
        ),
      ],
      if (facts.isEmpty) ...[
        const SizedBox(height: LwSpacing.lg),
        LwEmptyState(
          icon: Icons.bookmark_border,
          title: l.memoryEmptyTitle,
          body: l.memoryEmptyBody,
        ),
      ],
      if (proposed.isNotEmpty) ...[
        LwSectionHeader(l.memorySuggestionsHeader),
        for (final f in proposed)
          _FactTile(
            fact: f,
            block: keepBlock(f, memoryOn: memoryOn, sensitiveOn: sensitiveOn),
          ),
      ],
      if (saved.isNotEmpty) ...[
        LwSectionHeader(l.memorySavedHeader),
        for (final f in saved) _FactTile(fact: f, block: KeepBlock.none),
      ],
      if (facts.isNotEmpty) ...[
        const SizedBox(height: LwSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('memory-delete-all'),
            onPressed: () => _deleteAll(context, ref, l, facts),
            child: Text(l.memoryDeleteAll),
          ),
        ),
      ],
    ];
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    List<MemoryFact> facts,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.memoryDeleteAllTitle),
        content: Text(l.memoryDeleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.memoryCancel),
          ),
          TextButton(
            key: const Key('memory-delete-all-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.memoryDeleteAll),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _guard(
      context,
      l,
      () =>
          ref.read(memoryRepositoryProvider).deleteAll(facts.map((f) => f.id)),
    );
  }
}

Future<void> _guard(
  BuildContext context,
  AppLocalizations l,
  Future<void> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.memorySaveError)));
  }
}

class _ConsentSwitch extends ConsumerWidget {
  const _ConsentSwitch({
    super.key,
    required this.type,
    required this.value,
    required this.enabled,
  });

  final ConsentType type;
  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(type.title(l), style: t.titleMedium),
      subtitle: Text(type.body(l)!, style: t.bodySmall),
      // Each change is a new consent record; nothing is overwritten.
      onChanged: enabled
          ? (on) => _guard(
              context,
              l,
              () =>
                  ref.read(consentRepositoryProvider).record(type, granted: on),
            )
          : null,
    );
  }
}

class _FactTile extends ConsumerWidget {
  const _FactTile({required this.fact, required this.block});

  final MemoryFact fact;
  final KeepBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    final repo = ref.read(memoryRepositoryProvider);
    final proposed = fact.status == MemoryStatus.proposed;
    return Padding(
      key: Key('memory-fact-${fact.id}'),
      padding: const EdgeInsets.symmetric(vertical: LwSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(fact.fact, style: t.bodyLarge)),
              if (fact.sensitive) ...[
                const SizedBox(width: LwSpacing.xs),
                LwTag(l.memoryHealthTag),
              ],
            ],
          ),
          if (proposed && block == KeepBlock.needsSensitiveOptIn)
            Padding(
              padding: const EdgeInsets.only(top: LwSpacing.xxs),
              child: Text(
                l.memoryNeedsSensitive,
                style: t.bodySmall?.copyWith(color: p.textSecondary),
              ),
            ),
          Wrap(
            spacing: LwSpacing.xs,
            children: [
              if (proposed)
                Semantics(
                  label: l.memoryKeepSemantics(fact.fact),
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  child: FilledButton.tonal(
                    key: Key('memory-keep-${fact.id}'),
                    onPressed: block == KeepBlock.none
                        ? () => _guard(context, l, () => repo.keep(fact.id))
                        : null,
                    child: Text(l.memoryKeep),
                  ),
                ),
              Semantics(
                label: l.memoryDeleteSemantics(fact.fact),
                container: true,
                excludeSemantics: true,
                button: true,
                child: TextButton(
                  key: Key('memory-delete-${fact.id}'),
                  onPressed: () => _guard(
                    context,
                    l,
                    () => repo.delete(fact.id),
                    done: l.memoryDeleted,
                  ),
                  child: Text(l.memoryDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
