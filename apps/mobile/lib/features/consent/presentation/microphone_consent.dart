import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/consent_repository.dart';
import '../domain/consent.dart';

/// The microphone is a separate, revocable consent (FR-ONB-03): ask in the
/// app before any OS permission prompt, and record the answer. Returns true
/// when voice input may be used. Shared by every voice-typing screen.
Future<bool> ensureMicrophoneConsent(
  BuildContext context,
  WidgetRef ref,
) async {
  // One read straight from the store (an unwatched provider would pause).
  final records = await ref
      .read(consentRepositoryProvider)
      .watchRecords()
      .first;
  if (isGranted(currentConsents(records), ConsentType.microphone)) return true;
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.whyMicTitle),
      content: Text(l.whyMicBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.whyMicNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.whyMicAllow),
        ),
      ],
    ),
  );
  if (allow != true) return false;
  await ref
      .read(consentRepositoryProvider)
      .record(ConsentType.microphone, granted: true);
  return true;
}
