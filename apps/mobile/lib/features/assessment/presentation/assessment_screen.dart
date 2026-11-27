import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/assessment_data.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

/// The 10-minute check (ASM-01, D-114): one question at a time, a tap from
/// 1 to 5; the answers fill the Live Well Map. Nothing is typed.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  static const path = '/plan/check';

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  /// -1: the intro; questions.length: finished.
  int _i = -1;
  final _answers = <String, int>{};
  bool _saving = false;

  Future<void> _answer(List<AssessmentQuestion> qs, int value) async {
    _answers[qs[_i].id] = value;
    if (_i + 1 < qs.length) {
      setState(() => _i++);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(assessmentRepositoryProvider)
          .save(
            bankVersion: bankVersion(qs),
            answers: Map.of(_answers),
            scores: driverScores(qs, _answers),
          );
    } catch (_) {
      // Kept for this visit only; the map waits for a saved check.
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _i = qs.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final qs = ref.watch(assessmentQuestionsProvider).value ?? const [];
    final Widget body;
    if (qs.isEmpty) {
      body = Text(l.assessmentNoQuestions, key: const Key('check-empty'));
    } else if (_i < 0) {
      body = Column(
        key: const Key('check-intro'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.assessmentIntroTitle, style: t.headlineSmall),
          const SizedBox(height: LwSpacing.sm),
          Text(l.assessmentIntroBody(qs.length), style: t.bodyLarge),
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            key: const Key('check-start'),
            onPressed: () => setState(() => _i = 0),
            child: Text(l.assessmentStart),
          ),
        ],
      );
    } else if (_i >= qs.length) {
      body = Column(
        key: const Key('check-done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.assessmentDoneTitle, style: t.headlineSmall),
          const SizedBox(height: LwSpacing.sm),
          Text(l.assessmentDoneBody, style: t.bodyLarge),
          const SizedBox(height: LwSpacing.lg),
          FilledButton(
            key: const Key('check-see-map'),
            onPressed: () => context.go('/plan'),
            child: Text(l.assessmentSeeMap),
          ),
        ],
      );
    } else {
      final q = qs[_i];
      final labels = [
        l.assessmentScale1,
        l.assessmentScale2,
        l.assessmentScale3,
        l.assessmentScale4,
        l.assessmentScale5,
      ];
      body = Column(
        key: Key('check-q-${q.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_i + 1) / qs.length,
            semanticsLabel: l.assessmentProgress(_i + 1, qs.length),
          ),
          const SizedBox(height: LwSpacing.xs),
          Text(l.assessmentProgress(_i + 1, qs.length), style: t.bodySmall),
          const SizedBox(height: LwSpacing.md),
          Semantics(header: true, child: Text(q.text, style: t.titleLarge)),
          const SizedBox(height: LwSpacing.md),
          for (var v = 1; v <= 5; v++) ...[
            OutlinedButton(
              key: Key('check-answer-$v'),
              onPressed: _saving ? null : () => _answer(qs, v),
              child: Text('$v · ${labels[v - 1]}'),
            ),
            const SizedBox(height: LwSpacing.xs),
          ],
          if (_i > 0)
            TextButton(
              key: const Key('check-back'),
              onPressed: () => setState(() => _i--),
              child: Text(l.assessmentBack),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.assessmentTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LwSpacing.screenGutter),
          child: body,
        ),
      ),
    );
  }
}
