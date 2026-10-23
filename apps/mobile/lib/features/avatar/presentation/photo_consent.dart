import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';

/// "Make me from my photo" needs two separate, revocable consents before the
/// camera opens (FR-ONB-03, T-AVT-08e): the camera, and biometric
/// processing (making a coach from the face). Asked in plain words: what is
/// done with the photo, that it is deleted right after (7 days at most),
/// and how to delete the coach. Both are recorded; the server checks them
/// again. Returns true when allowed.
Future<bool> ensurePhotoConsent(BuildContext context, WidgetRef ref) async {
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
      key: const Key('photo-consent'),
      title: Text(l.photoConsentTitle),
      content: SingleChildScrollView(child: Text(l.photoConsentBody)),
      actions: [
        TextButton(
          key: const Key('photo-consent-no'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.photoConsentNotNow),
        ),
        FilledButton(
          key: const Key('photo-consent-yes'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.photoConsentAllow),
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
