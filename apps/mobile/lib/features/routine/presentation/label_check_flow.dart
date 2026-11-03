import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../safety/data/safety_rules_provider.dart';
import '../../safety/presentation/safety_screens.dart';
import '../data/routine_repository.dart';
import '../domain/label_check.dart';
import 'routine_sheets.dart';

/// Runs the short-label check (D-46) on words a person typed for a routine
/// step, a habit or a goal. A red flag shows the safety response (with the
/// person's region's contacts) and calls [notSaved]; blocked words come back
/// as [LabelTryAgain] with [blocked]'s message, so the person can reword.
Future<LabelOutcome> runLabelCheck(
  BuildContext context,
  WidgetRef ref,
  String label, {
  required String Function(LabelKind kind) blocked,
  required VoidCallback notSaved,
}) async {
  final rules = await ref.read(safetyRulesProvider.future);
  final labels = await ref.read(labelRulesProvider.future);
  switch (checkLabel(label, rules, labels)) {
    case LabelOk():
      return const LabelAccepted();
    case LabelBlocked(:final kind):
      return LabelTryAgain(blocked(kind));
    case LabelRedFlag(:final result):
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      final region = uid == null
          ? null
          : (await ref.read(profileRepositoryProvider).get(uid))?.region;
      if (!context.mounted) return const LabelStopped();
      await showSafetyResponse(context, result, rules.contactsFor(region));
      if (context.mounted) notSaved();
      return const LabelStopped();
  }
}
