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

  @override
  String get aboutTitle => 'What Live Well does';

  @override
  String get aboutDoesHeader => 'Live Well helps you';

  @override
  String get aboutDoes1 =>
      'Build small daily habits with Dr. Gokula\'s MY GOAL DO IT approach and the 8 drivers of health.';

  @override
  String get aboutDoes2 =>
      'Talk with a personal coach that speaks, listens and remembers only what you allow.';

  @override
  String get aboutDoes3 =>
      'Learn from the Live Well book and reviewed lessons.';

  @override
  String get aboutDoes4 =>
      'Go deeper on the Live Well portal when you want to.';

  @override
  String get aboutDoesNotHeader => 'Live Well does not';

  @override
  String get aboutDoesNot1 => 'Diagnose illness or replace your doctor.';

  @override
  String get aboutDoesNot2 => 'Give medication, dose or supplement advice.';

  @override
  String get aboutDoesNot3 => 'Keep your medical records.';

  @override
  String get aboutDoesNot4 =>
      'Sell your data or show ads from other companies.';

  @override
  String get aboutEmergency =>
      'In an emergency, call your local emergency number.';

  @override
  String get commonContinue => 'Continue';

  @override
  String get ageTitle => 'Are you 18 or older?';

  @override
  String get ageBody =>
      'Live Well is for adults. We ask before you create an account, so nothing is saved for anyone under 18.';

  @override
  String get ageYes => 'Yes, I\'m 18 or older';

  @override
  String get ageNo => 'No, I\'m under 18';

  @override
  String get under18Title => 'Live Well is for adults';

  @override
  String get under18Body =>
      'Thank you for your interest. Live Well is made for people 18 and older, so we haven\'t saved anything. If you\'d like support with your health, a parent, school nurse or doctor is a great place to start.';

  @override
  String get under18Back => 'Back to start';

  @override
  String get legalTitle => 'Before you start';

  @override
  String get legalBody =>
      'Please read and accept each of these. Your acceptance is saved with the version and the date.';

  @override
  String get legalRead => 'Read';

  @override
  String get legalAcceptAll => 'Accept and continue';

  @override
  String get legalAcceptHint => 'Tick all four to continue.';

  @override
  String legalVersion(String version) {
    return 'Version $version';
  }

  @override
  String get legalLoadError =>
      'We couldn\'t open this document. Please try again.';

  @override
  String get signInTitle => 'Sign in or create an account';

  @override
  String get signInBody =>
      'Use your phone number, email or Google. If you already use the Live Well portal, use the same phone number or email.';

  @override
  String get signInPhone => 'Continue with phone';

  @override
  String get signInEmail => 'Continue with email';

  @override
  String get signInGoogle => 'Continue with Google';

  @override
  String get signInApple => 'Continue with Apple';

  @override
  String get emailTitle => 'Continue with email';

  @override
  String get emailModeSignIn => 'Sign in';

  @override
  String get emailModeCreate => 'Create account';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String resetSent(String email) {
    return 'We sent a reset link to $email.';
  }

  @override
  String get emailInvalidMsg => 'Enter a valid email address.';

  @override
  String get passwordShortMsg => 'Use at least 8 characters.';

  @override
  String get phoneTitle => 'Continue with phone';

  @override
  String get phoneCountryLabel => 'Country';

  @override
  String get countryIndia => 'India (+91)';

  @override
  String get countryUs => 'United States (+1)';

  @override
  String get phoneNumberLabel => 'Mobile number';

  @override
  String get phoneInvalidMsg => 'Enter a valid mobile number for this country.';

  @override
  String get phoneSendCode => 'Send code';

  @override
  String get phoneSmsNote =>
      'We\'ll text you a 6-digit code. Message rates may apply.';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeBody(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get codeLabel => '6-digit code';

  @override
  String get codeVerify => 'Verify';

  @override
  String codeResendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get codeResend => 'Resend code';

  @override
  String get codeChangeNumber => 'Change number';

  @override
  String get codeInvalidMsg => 'Enter the 6 digits from the text message.';

  @override
  String get authErrorInvalidEmail => 'That email address doesn\'t look right.';

  @override
  String get authErrorWrongCredentials =>
      'That email and password don\'t match. Try again or reset your password.';

  @override
  String get authErrorEmailInUse =>
      'There\'s already an account with this email. Sign in instead.';

  @override
  String get authErrorWeakPassword =>
      'Choose a stronger password with at least 8 characters.';

  @override
  String get authErrorInvalidPhone => 'That phone number doesn\'t look right.';

  @override
  String get authErrorWrongCode =>
      'That code isn\'t right. Check the text message and try again.';

  @override
  String get authErrorCodeExpired => 'That code has expired. Send a new one.';

  @override
  String get authErrorTooMany =>
      'Too many tries. Please wait a few minutes and try again.';

  @override
  String get authErrorNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get authErrorMethodDisabled =>
      'This sign-in option isn\'t available yet.';

  @override
  String get authErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get accountSetupError =>
      'We couldn\'t finish setting up your account. Please try again.';

  @override
  String get whyTitle => 'Your Why';

  @override
  String get whyHeading => 'What matters most to you?';

  @override
  String get whyBody =>
      'Your Why is the reason behind your habits. Your coach will remind you of it on hard days.';

  @override
  String get whyFieldLabel => 'My Why';

  @override
  String get whyHint => 'I want to...';

  @override
  String get whySuggestionsLabel =>
      'Need an idea? Tap one, then make it yours.';

  @override
  String get whySuggestion1 => 'I want energy to travel with my family.';

  @override
  String get whySuggestion2 => 'I want to stay active for my grandchildren.';

  @override
  String get whySuggestion3 =>
      'I want to sleep well and wake up feeling rested.';

  @override
  String get whySuggestion4 =>
      'I want to feel strong and confident in my body.';

  @override
  String get whySuggestion5 => 'I want to stay healthy for the people I love.';

  @override
  String get whySave => 'Save my Why';

  @override
  String get whyTooShort => 'Write a few words about what matters to you.';

  @override
  String get whyDictate => 'Speak instead';

  @override
  String get whyListening => 'Listening. Tap to stop.';

  @override
  String get whyMicTitle => 'Use your microphone?';

  @override
  String get whyMicBody =>
      'Live Well uses the microphone only when you tap to speak, to turn your words into text. You can turn this off any time in Privacy and consents.';

  @override
  String get whyMicAllow => 'Allow';

  @override
  String get whyMicNotNow => 'Not now';

  @override
  String get whyDictationUnavailable =>
      'Voice typing isn\'t available on this phone. You can type instead.';

  @override
  String get whySaveError => 'We couldn\'t save your Why. Please try again.';

  @override
  String get homeWhyEyebrow => 'Your Why';
}
