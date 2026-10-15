import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';

/// A selfie needs two separate, revocable consents (FR-ONB-03): the camera,
/// and biometric data (reading face features). Asked in plain words before
/// the OS camera prompt; both are recorded. Returns true when allowed.
Future<bool> ensureSelfieConsent(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(consentRepositoryProvider);
  final current = currentConsents(await repo.watchRecords().first);
  if (isGranted(current, ConsentType.camera) &&
      isGranted(current, ConsentType.biometric)) {
    return true;
  }
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.avatarSelfieConsentTitle),
      content: Text(l.avatarSelfieConsentBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.avatarSelfieNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.avatarSelfieAllow),
        ),
      ],
    ),
  );
  if (allow != true) return false;
  if (!isGranted(current, ConsentType.camera)) {
    await repo.record(ConsentType.camera, granted: true);
  }
  if (!isGranted(current, ConsentType.biometric)) {
    await repo.record(ConsentType.biometric, granted: true);
  }
  return true;
}
