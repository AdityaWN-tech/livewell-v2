// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Live Well';

  @override
  String get taglineHealth => 'Health.';

  @override
  String get taglineHabit => 'Habit.';

  @override
  String get taglineHappiness => 'Happiness.';

  @override
  String get splashSemanticLabel => 'Live Well. Health. Habit. Happiness.';

  @override
  String get welcomeTitle => 'Your daily companion for health and happiness.';

  @override
  String get welcomeGetStarted => 'Get started';

  @override
  String get welcomeHaveAccount => 'I already have an account';

  @override
  String get startupErrorTitle => 'We couldn\'t start Live Well';

  @override
  String get startupErrorBody => 'Please check your connection and try again.';

  @override
  String get startupErrorRetry => 'Try again';

  @override
  String get devDesignTokens => 'Design tokens';

  @override
  String get tabHome => 'Home';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabTrack => 'Track';

  @override
  String get tabLearn => 'Learn';

  @override
  String get tabCare => 'Care';

  @override
  String get homeEmptyTitle => 'Your day starts here';

  @override
  String get homeEmptyBody =>
      'Your morning briefing, one next step and a quick check-in will show up here.';

  @override
  String get planEmptyTitle => 'Your plan';

  @override
  String get planEmptyBody =>
      'Your Live Well Map, your 30-day goal and your daily habits will live here.';

  @override
  String get trackEmptyTitle => 'Your progress';

  @override
  String get trackEmptyBody =>
      'Your check-ins, habits and the numbers you log will show here as simple charts.';

  @override
  String get learnEmptyTitle => 'Learn something small';

  @override
  String get learnEmptyBody =>
      'Short lessons from the Live Well book, audio and breathing sessions will be here.';

  @override
  String get careEmptyTitle => 'Care and support';

  @override
  String get careEmptyBody =>
      'Talk with your coach, see what it remembers, and find safety and clinician help here.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPrivacy => 'Privacy and consents';

  @override
  String get settingsPrivacyBody =>
      'Choose what Live Well may use. Change it any time.';

  @override
  String get consentsIntro =>
      'Each switch is your choice, and you can change it any time. Every change is saved with the date and the wording you saw.';

  @override
  String get consentsDraftNote =>
      'Draft wording. The final text comes after legal review.';

  @override
  String get consentsOptionalHeader => 'Your choices';

  @override
  String get consentsLegalHeader => 'Accepted to use Live Well';

  @override
  String consentLegalAccepted(String version) {
    return 'Accepted · version $version';
  }

  @override
  String get consentLegalNotAccepted => 'Not accepted yet';

  @override
  String get consentLegalWithdrawNote =>
      'These are needed to use Live Well. To withdraw, close your account from My data.';

  @override
  String get consentSaveError =>
      'We couldn\'t save that change. Please try again.';

  @override
  String get consentLoadError =>
      'We couldn\'t load your choices. Please try again.';

  @override
  String get consentNotificationsTitle => 'Reminders and nudges';

  @override
  String get consentNotificationsBody =>
      'Lets Live Well send your briefing, check-in and habit reminders. You choose the times and quiet hours.';

  @override
  String get consentHealthDataTitle => 'Health data';

  @override
  String get consentHealthDataBody =>
      'Lets Live Well read steps, sleep and activity from Apple Health or Health Connect for your tracking.';

  @override
  String get consentCameraTitle => 'Camera';

  @override
  String get consentCameraBody =>
      'Used only if you make an avatar from a selfie.';

  @override
  String get consentMicrophoneTitle => 'Microphone';

  @override
  String get consentMicrophoneBody =>
      'Used when you talk to your coach or answer a reflection by voice.';

  @override
  String get consentBiometricTitle => 'Face and voice models';

  @override
  String get consentBiometricBody =>
      'Needed to make an avatar from your face or a copy of a voice. You can delete them any time.';

  @override
  String get consentPortalLinkingTitle => 'Link to the Live Well portal';

  @override
  String get consentPortalLinkingBody =>
      'Connects your portal account so your coach can suggest courses that fit. Your health data is never shared with the portal.';

  @override
  String get consentMarketingTitle => 'News and offers';

  @override
  String get consentMarketingBody =>
      'Occasional emails about new Live Well courses and programs.';

  @override
  String get consentAnalyticsTitle => 'Help improve the app';

  @override
  String get consentAnalyticsBody =>
      'Shares anonymous usage counts, never your health details.';

  @override
  String get consentTermsTitle => 'Terms of use';

  @override
  String get consentPrivacyTitle => 'Privacy policy';

  @override
  String get consentMedicalDisclaimerTitle => 'Medical disclaimer';

  @override
  String get consentAiDisclosureTitle => 'AI disclosure';

  @override
  String get devPreviewApp => 'Preview the app (dev build only)';

  @override
  String get devPreviewNotSaved => 'Preview mode: changes here are not saved.';
}
