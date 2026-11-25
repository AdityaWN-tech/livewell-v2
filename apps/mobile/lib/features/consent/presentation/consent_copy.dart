import '../../../l10n/app_localizations.dart';
import '../domain/consent.dart';

/// Plain-language title and explanation for each consent type.
extension ConsentCopy on ConsentType {
  String title(AppLocalizations l) => switch (this) {
    ConsentType.terms => l.consentTermsTitle,
    ConsentType.privacy => l.consentPrivacyTitle,
    ConsentType.medicalDisclaimer => l.consentMedicalDisclaimerTitle,
    ConsentType.aiDisclosure => l.consentAiDisclosureTitle,
    ConsentType.notifications => l.consentNotificationsTitle,
    ConsentType.healthData => l.consentHealthDataTitle,
    ConsentType.camera => l.consentCameraTitle,
    ConsentType.microphone => l.consentMicrophoneTitle,
    ConsentType.biometric => l.consentBiometricTitle,
    ConsentType.portalLinking => l.consentPortalLinkingTitle,
    ConsentType.marketing => l.consentMarketingTitle,
    ConsentType.analytics => l.consentAnalyticsTitle,
    ConsentType.memory => l.consentMemoryTitle,
    ConsentType.memorySensitive => l.consentMemorySensitiveTitle,
  };

  /// Null for the legal documents (their full text is shown elsewhere).
  String? body(AppLocalizations l) => switch (this) {
    ConsentType.notifications => l.consentNotificationsBody,
    ConsentType.healthData => l.consentHealthDataBody,
    ConsentType.camera => l.consentCameraBody,
    ConsentType.microphone => l.consentMicrophoneBody,
    ConsentType.biometric => l.consentBiometricBody,
    ConsentType.portalLinking => l.consentPortalLinkingBody,
    ConsentType.marketing => l.consentMarketingBody,
    ConsentType.analytics => l.consentAnalyticsBody,
    ConsentType.memory => l.consentMemoryBody,
    ConsentType.memorySensitive => l.consentMemorySensitiveBody,
    _ => null,
  };

  /// What revoking deletes or stops on our side (spec 16.3, D-76), shown
  /// before the switch goes off. Null when nothing is held server-side (the
  /// app simply stops: reminders, Health reads, analytics).
  String? revokeEffect(AppLocalizations l) => switch (this) {
    ConsentType.camera => l.consentRevokeCamera,
    ConsentType.microphone => l.consentRevokeMicrophone,
    ConsentType.biometric => l.consentRevokeBiometric,
    ConsentType.portalLinking => l.consentRevokePortalLinking,
    ConsentType.marketing => l.consentRevokeMarketing,
    _ => null,
  };
}
