import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Well'**
  String get appTitle;

  /// No description provided for @taglineHealth.
  ///
  /// In en, this message translates to:
  /// **'Health.'**
  String get taglineHealth;

  /// No description provided for @taglineHabit.
  ///
  /// In en, this message translates to:
  /// **'Habit.'**
  String get taglineHabit;

  /// No description provided for @taglineHappiness.
  ///
  /// In en, this message translates to:
  /// **'Happiness.'**
  String get taglineHappiness;

  /// Read once by screen readers while the logo reveal plays.
  ///
  /// In en, this message translates to:
  /// **'Live Well. Health. Habit. Happiness.'**
  String get splashSemanticLabel;

  /// Welcome screen headline (spec 5.2 step 1).
  ///
  /// In en, this message translates to:
  /// **'Your daily companion for health and happiness.'**
  String get welcomeTitle;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get welcomeGetStarted;

  /// No description provided for @welcomeHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeHaveAccount;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t start Live Well'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get startupErrorBody;

  /// No description provided for @startupErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startupErrorRetry;

  /// No description provided for @devDesignTokens.
  ///
  /// In en, this message translates to:
  /// **'Design tokens'**
  String get devDesignTokens;

  /// No description provided for @devIllustrations.
  ///
  /// In en, this message translates to:
  /// **'Illustrations'**
  String get devIllustrations;

  /// Bottom navigation tabs (spec 14.2).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @tabTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get tabTrack;

  /// No description provided for @tabLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get tabLearn;

  /// No description provided for @tabCare.
  ///
  /// In en, this message translates to:
  /// **'Care'**
  String get tabCare;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and consents'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose what Live Well may use. Change it any time.'**
  String get settingsPrivacyBody;

  /// No description provided for @consentsIntro.
  ///
  /// In en, this message translates to:
  /// **'Each switch is your choice, and you can change it any time. Every change is saved with the date and the wording you saw.'**
  String get consentsIntro;

  /// No description provided for @consentsDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Draft wording. The final text comes after legal review.'**
  String get consentsDraftNote;

  /// No description provided for @consentsOptionalHeader.
  ///
  /// In en, this message translates to:
  /// **'Your choices'**
  String get consentsOptionalHeader;

  /// No description provided for @consentsLegalHeader.
  ///
  /// In en, this message translates to:
  /// **'Accepted to use Live Well'**
  String get consentsLegalHeader;

  /// No description provided for @consentLegalAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted · version {version}'**
  String consentLegalAccepted(String version);

  /// No description provided for @consentLegalNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted yet'**
  String get consentLegalNotAccepted;

  /// No description provided for @consentLegalWithdrawNote.
  ///
  /// In en, this message translates to:
  /// **'These are needed to use Live Well. To withdraw, close your account from My data.'**
  String get consentLegalWithdrawNote;

  /// No description provided for @consentSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save that change. Please try again.'**
  String get consentSaveError;

  /// No description provided for @consentLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your choices. Please try again.'**
  String get consentLoadError;

  /// No description provided for @consentNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders and nudges'**
  String get consentNotificationsTitle;

  /// No description provided for @consentNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Lets Live Well send your briefing, check-in and habit reminders. You choose the times and quiet hours.'**
  String get consentNotificationsBody;

  /// No description provided for @consentHealthDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get consentHealthDataTitle;

  /// No description provided for @consentHealthDataBody.
  ///
  /// In en, this message translates to:
  /// **'Lets Live Well read steps, sleep and activity from Apple Health or Health Connect for your tracking.'**
  String get consentHealthDataBody;

  /// No description provided for @consentCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get consentCameraTitle;

  /// No description provided for @consentCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Used only if you make an avatar from a selfie.'**
  String get consentCameraBody;

  /// No description provided for @consentMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get consentMicrophoneTitle;

  /// No description provided for @consentMicrophoneBody.
  ///
  /// In en, this message translates to:
  /// **'Used when you talk to your coach or answer a reflection by voice.'**
  String get consentMicrophoneBody;

  /// No description provided for @consentBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Face and voice models'**
  String get consentBiometricTitle;

  /// No description provided for @consentBiometricBody.
  ///
  /// In en, this message translates to:
  /// **'Needed to make an avatar from your face or a copy of a voice. You can delete them any time.'**
  String get consentBiometricBody;

  /// No description provided for @consentPortalLinkingTitle.
  ///
  /// In en, this message translates to:
  /// **'Link to the Live Well portal'**
  String get consentPortalLinkingTitle;

  /// No description provided for @consentPortalLinkingBody.
  ///
  /// In en, this message translates to:
  /// **'Connects your portal account so your coach can suggest courses that fit. Your health data is never shared with the portal.'**
  String get consentPortalLinkingBody;

  /// No description provided for @consentMarketingTitle.
  ///
  /// In en, this message translates to:
  /// **'News and offers'**
  String get consentMarketingTitle;

  /// No description provided for @consentMarketingBody.
  ///
  /// In en, this message translates to:
  /// **'Occasional emails about new Live Well courses and programs.'**
  String get consentMarketingBody;

  /// No description provided for @consentAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app'**
  String get consentAnalyticsTitle;

  /// No description provided for @consentAnalyticsBody.
  ///
  /// In en, this message translates to:
  /// **'Shares anonymous usage counts, never your health details.'**
  String get consentAnalyticsBody;

  /// No description provided for @consentTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get consentTermsTitle;

  /// No description provided for @consentPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get consentPrivacyTitle;

  /// No description provided for @consentMedicalDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical disclaimer'**
  String get consentMedicalDisclaimerTitle;

  /// No description provided for @consentAiDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'AI disclosure'**
  String get consentAiDisclosureTitle;

  /// No description provided for @devPreviewApp.
  ///
  /// In en, this message translates to:
  /// **'Preview the app (dev build only)'**
  String get devPreviewApp;

  /// No description provided for @devPreviewNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Preview mode: changes here are not saved.'**
  String get devPreviewNotSaved;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'What Live Well does'**
  String get aboutTitle;

  /// No description provided for @aboutDoesHeader.
  ///
  /// In en, this message translates to:
  /// **'Live Well helps you'**
  String get aboutDoesHeader;

  /// No description provided for @aboutDoes1.
  ///
  /// In en, this message translates to:
  /// **'Build small daily habits with Dr. Gokula\'s MY GOAL DO IT approach and the 8 drivers of health.'**
  String get aboutDoes1;

  /// No description provided for @aboutDoes2.
  ///
  /// In en, this message translates to:
  /// **'Talk with a personal coach that speaks, listens and remembers only what you allow.'**
  String get aboutDoes2;

  /// No description provided for @aboutDoes3.
  ///
  /// In en, this message translates to:
  /// **'Learn from the Live Well book and reviewed lessons.'**
  String get aboutDoes3;

  /// No description provided for @aboutDoes4.
  ///
  /// In en, this message translates to:
  /// **'Go deeper on the Live Well portal when you want to.'**
  String get aboutDoes4;

  /// No description provided for @aboutDoesNotHeader.
  ///
  /// In en, this message translates to:
  /// **'Live Well does not'**
  String get aboutDoesNotHeader;

  /// No description provided for @aboutDoesNot1.
  ///
  /// In en, this message translates to:
  /// **'Diagnose illness or replace your doctor.'**
  String get aboutDoesNot1;

  /// No description provided for @aboutDoesNot2.
  ///
  /// In en, this message translates to:
  /// **'Give medication, dose or supplement advice.'**
  String get aboutDoesNot2;

  /// No description provided for @aboutDoesNot3.
  ///
  /// In en, this message translates to:
  /// **'Keep your medical records.'**
  String get aboutDoesNot3;

  /// No description provided for @aboutDoesNot4.
  ///
  /// In en, this message translates to:
  /// **'Sell your data or show ads from other companies.'**
  String get aboutDoesNot4;

  /// No description provided for @aboutEmergency.
  ///
  /// In en, this message translates to:
  /// **'In an emergency, call your local emergency number.'**
  String get aboutEmergency;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @ageTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you 18 or older?'**
  String get ageTitle;

  /// No description provided for @ageBody.
  ///
  /// In en, this message translates to:
  /// **'Live Well is for adults. We ask before you create an account, so nothing is saved for anyone under 18.'**
  String get ageBody;

  /// No description provided for @ageYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m 18 or older'**
  String get ageYes;

  /// No description provided for @ageNo.
  ///
  /// In en, this message translates to:
  /// **'No, I\'m under 18'**
  String get ageNo;

  /// No description provided for @under18Title.
  ///
  /// In en, this message translates to:
  /// **'Live Well is for adults'**
  String get under18Title;

  /// No description provided for @under18Body.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your interest. Live Well is made for people 18 and older, so we haven\'t saved anything. If you\'d like support with your health, a parent, school nurse or doctor is a great place to start.'**
  String get under18Body;

  /// No description provided for @under18Back.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get under18Back;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get legalTitle;

  /// No description provided for @legalBody.
  ///
  /// In en, this message translates to:
  /// **'Please read and accept each of these. Your acceptance is saved with the version and the date.'**
  String get legalBody;

  /// No description provided for @legalRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get legalRead;

  /// No description provided for @legalAcceptAll.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get legalAcceptAll;

  /// No description provided for @legalAcceptHint.
  ///
  /// In en, this message translates to:
  /// **'Tick all four to continue.'**
  String get legalAcceptHint;

  /// No description provided for @legalVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String legalVersion(String version);

  /// No description provided for @legalLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open this document. Please try again.'**
  String get legalLoadError;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Use your phone number, email, Google or Apple. If you already use the Live Well portal, use the same phone number or email.'**
  String get signInBody;

  /// No description provided for @signInPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get signInPhone;

  /// No description provided for @signInEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get signInEmail;

  /// No description provided for @signInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInGoogle;

  /// No description provided for @signInApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInApple;

  /// No description provided for @emailTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get emailTitle;

  /// No description provided for @emailModeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get emailModeSignIn;

  /// No description provided for @emailModeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get emailModeCreate;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHint;

  /// No description provided for @passwordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to {email}.'**
  String resetSent(String email);

  /// No description provided for @emailInvalidMsg.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalidMsg;

  /// No description provided for @passwordShortMsg.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get passwordShortMsg;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue with phone'**
  String get phoneTitle;

  /// No description provided for @phoneCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get phoneCountryLabel;

  /// No description provided for @countryIndia.
  ///
  /// In en, this message translates to:
  /// **'India (+91)'**
  String get countryIndia;

  /// No description provided for @countryUs.
  ///
  /// In en, this message translates to:
  /// **'United States (+1)'**
  String get countryUs;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneInvalidMsg.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number for this country.'**
  String get phoneInvalidMsg;

  /// No description provided for @phoneSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get phoneSendCode;

  /// No description provided for @phoneSmsNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text you a 6-digit code. Message rates may apply.'**
  String get phoneSmsNote;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeTitle;

  /// No description provided for @codeBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}.'**
  String codeBody(String phone);

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @codeVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get codeVerify;

  /// No description provided for @codeResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String codeResendIn(int seconds);

  /// No description provided for @codeResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get codeResend;

  /// No description provided for @codeChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get codeChangeNumber;

  /// No description provided for @codeInvalidMsg.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits from the text message.'**
  String get codeInvalidMsg;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email and password don\'t match. Try again or reset your password.'**
  String get authErrorWrongCredentials;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'There\'s already an account with this email. Sign in instead.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password with at least 8 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'That phone number doesn\'t look right.'**
  String get authErrorInvalidPhone;

  /// No description provided for @authErrorWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check the text message and try again.'**
  String get authErrorWrongCode;

  /// No description provided for @authErrorCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Send a new one.'**
  String get authErrorCodeExpired;

  /// No description provided for @authErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Please wait a few minutes and try again.'**
  String get authErrorTooMany;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorMethodDisabled.
  ///
  /// In en, this message translates to:
  /// **'This sign-in option isn\'t available yet.'**
  String get authErrorMethodDisabled;

  /// No description provided for @authErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorUnknown;

  /// No description provided for @accountSetupError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish setting up your account. Please try again.'**
  String get accountSetupError;

  /// No description provided for @whyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Why'**
  String get whyTitle;

  /// No description provided for @whyHeading.
  ///
  /// In en, this message translates to:
  /// **'What matters most to you?'**
  String get whyHeading;

  /// No description provided for @whyBody.
  ///
  /// In en, this message translates to:
  /// **'Your Why is the reason behind your habits. Your coach will remind you of it on hard days.'**
  String get whyBody;

  /// No description provided for @whyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'My Why'**
  String get whyFieldLabel;

  /// No description provided for @whyHint.
  ///
  /// In en, this message translates to:
  /// **'I want to...'**
  String get whyHint;

  /// No description provided for @whySuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Need an idea? Tap one, then make it yours.'**
  String get whySuggestionsLabel;

  /// No description provided for @whySuggestion1.
  ///
  /// In en, this message translates to:
  /// **'I want energy to travel with my family.'**
  String get whySuggestion1;

  /// No description provided for @whySuggestion2.
  ///
  /// In en, this message translates to:
  /// **'I want to stay active for my grandchildren.'**
  String get whySuggestion2;

  /// No description provided for @whySuggestion3.
  ///
  /// In en, this message translates to:
  /// **'I want to sleep well and wake up feeling rested.'**
  String get whySuggestion3;

  /// No description provided for @whySuggestion4.
  ///
  /// In en, this message translates to:
  /// **'I want to feel strong and confident in my body.'**
  String get whySuggestion4;

  /// No description provided for @whySuggestion5.
  ///
  /// In en, this message translates to:
  /// **'I want to stay healthy for the people I love.'**
  String get whySuggestion5;

  /// No description provided for @whySave.
  ///
  /// In en, this message translates to:
  /// **'Save my Why'**
  String get whySave;

  /// No description provided for @whyTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a few words about what matters to you.'**
  String get whyTooShort;

  /// No description provided for @whyDictate.
  ///
  /// In en, this message translates to:
  /// **'Speak instead'**
  String get whyDictate;

  /// No description provided for @whyListening.
  ///
  /// In en, this message translates to:
  /// **'Listening. Tap to stop.'**
  String get whyListening;

  /// No description provided for @whyMicTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your microphone?'**
  String get whyMicTitle;

  /// No description provided for @whyMicBody.
  ///
  /// In en, this message translates to:
  /// **'Live Well uses the microphone only when you tap to speak, to turn your words into text. You can turn this off any time in Privacy and consents.'**
  String get whyMicBody;

  /// No description provided for @whyMicAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get whyMicAllow;

  /// No description provided for @whyMicNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get whyMicNotNow;

  /// No description provided for @whyDictationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice typing isn\'t available on this phone. You can type instead.'**
  String get whyDictationUnavailable;

  /// No description provided for @whySaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your Why. Please try again.'**
  String get whySaveError;

  /// No description provided for @homeWhyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your Why'**
  String get homeWhyEyebrow;

  /// No description provided for @safetyEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'This could be an emergency'**
  String get safetyEmergencyTitle;

  /// No description provided for @safetyEmergencyBody.
  ///
  /// In en, this message translates to:
  /// **'Please call for emergency help now. If you can, unlock your door and ask someone to stay with you.'**
  String get safetyEmergencyBody;

  /// No description provided for @safetyCallNumber.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String safetyCallNumber(String number);

  /// No description provided for @safetyCallNumberIn.
  ///
  /// In en, this message translates to:
  /// **'Call {number} in {country}'**
  String safetyCallNumberIn(String number, String country);

  /// No description provided for @safetyCrisisTitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to face this alone'**
  String get safetyCrisisTitle;

  /// No description provided for @safetyCrisisBody.
  ///
  /// In en, this message translates to:
  /// **'If you\'re thinking about suicide or hurting yourself, please reach out to someone right now. It\'s free and confidential, and they\'re there day and night.'**
  String get safetyCrisisBody;

  /// No description provided for @safetyCrisisCall.
  ///
  /// In en, this message translates to:
  /// **'Call {name}: {number}'**
  String safetyCrisisCall(String name, String number);

  /// No description provided for @safetyCrisisText.
  ///
  /// In en, this message translates to:
  /// **'Text {number}'**
  String safetyCrisisText(String number);

  /// No description provided for @safetyCrisisDanger.
  ///
  /// In en, this message translates to:
  /// **'If you\'re in danger right now, call emergency services.'**
  String get safetyCrisisDanger;

  /// No description provided for @safetyEdTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s take care of you first'**
  String get safetyEdTitle;

  /// No description provided for @safetyEdBody.
  ///
  /// In en, this message translates to:
  /// **'It sounds like food or your body may feel hard right now. Live Well won\'t help with very low-calorie or fast weight-loss plans. A doctor or an eating-disorder specialist can support you, and you deserve that support.'**
  String get safetyEdBody;

  /// No description provided for @safetyMedTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine changes are for you and your prescriber'**
  String get safetyMedTitle;

  /// No description provided for @safetyMedBody.
  ///
  /// In en, this message translates to:
  /// **'Please don\'t start, stop or change any medicine or supplement without talking to the doctor who prescribed it. Live Well can help with daily habits alongside your treatment.'**
  String get safetyMedBody;

  /// No description provided for @safetyComplexTitle.
  ///
  /// In en, this message translates to:
  /// **'Check with your clinician first'**
  String get safetyComplexTitle;

  /// No description provided for @safetyComplexBody.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy and some health conditions change what\'s safe for you. Please talk to your doctor or midwife before changing how you eat or move.'**
  String get safetyComplexBody;

  /// No description provided for @safetyBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get safetyBack;

  /// No description provided for @safetyChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get safetyChangeIt;

  /// No description provided for @safetySaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save my Why'**
  String get safetySaveAnyway;

  /// No description provided for @countryIndiaName.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get countryIndiaName;

  /// No description provided for @safetyCallFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t start the call. Please dial {number}.'**
  String safetyCallFailed(String number);

  /// No description provided for @settingsDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloper;

  /// No description provided for @settingsDeveloperBody.
  ///
  /// In en, this message translates to:
  /// **'Tools for building the app. Only in the dev build.'**
  String get settingsDeveloperBody;

  /// No description provided for @checkinResponseHigh.
  ///
  /// In en, this message translates to:
  /// **'Love that energy. Let\'s use it well today.'**
  String get checkinResponseHigh;

  /// No description provided for @checkinResponseSteady.
  ///
  /// In en, this message translates to:
  /// **'Thanks for checking in. One small step is plenty today.'**
  String get checkinResponseSteady;

  /// No description provided for @checkinResponseGentle.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling me. Let\'s keep today gentle.'**
  String get checkinResponseGentle;

  /// No description provided for @checkinMoodQuestionNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, how are you feeling today?'**
  String checkinMoodQuestionNamed(String name);

  /// No description provided for @checkinMoodQuestion.
  ///
  /// In en, this message translates to:
  /// **'Hi, how are you feeling today?'**
  String get checkinMoodQuestion;

  /// No description provided for @checkinMood1.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get checkinMood1;

  /// No description provided for @checkinMood2.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get checkinMood2;

  /// No description provided for @checkinMood3.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get checkinMood3;

  /// No description provided for @checkinMood4.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get checkinMood4;

  /// No description provided for @checkinMood5.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get checkinMood5;

  /// No description provided for @checkinEnergyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How is your energy?'**
  String get checkinEnergyQuestion;

  /// No description provided for @checkinEnergy1.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get checkinEnergy1;

  /// No description provided for @checkinEnergy2.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get checkinEnergy2;

  /// No description provided for @checkinEnergy3.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get checkinEnergy3;

  /// No description provided for @checkinEnergy4.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get checkinEnergy4;

  /// No description provided for @checkinEnergy5.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get checkinEnergy5;

  /// No description provided for @checkinSleepQuestion.
  ///
  /// In en, this message translates to:
  /// **'How did you sleep last night?'**
  String get checkinSleepQuestion;

  /// No description provided for @checkinSleep1.
  ///
  /// In en, this message translates to:
  /// **'Very badly'**
  String get checkinSleep1;

  /// No description provided for @checkinSleep2.
  ///
  /// In en, this message translates to:
  /// **'Badly'**
  String get checkinSleep2;

  /// No description provided for @checkinSleep3.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get checkinSleep3;

  /// No description provided for @checkinSleep4.
  ///
  /// In en, this message translates to:
  /// **'Well'**
  String get checkinSleep4;

  /// No description provided for @checkinSleep5.
  ///
  /// In en, this message translates to:
  /// **'Very well'**
  String get checkinSleep5;

  /// No description provided for @checkinStressQuestion.
  ///
  /// In en, this message translates to:
  /// **'How stressed do you feel?'**
  String get checkinStressQuestion;

  /// No description provided for @checkinStress1.
  ///
  /// In en, this message translates to:
  /// **'Not at all'**
  String get checkinStress1;

  /// No description provided for @checkinStress2.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get checkinStress2;

  /// No description provided for @checkinStress3.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get checkinStress3;

  /// No description provided for @checkinStress4.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get checkinStress4;

  /// No description provided for @checkinStress5.
  ///
  /// In en, this message translates to:
  /// **'Very high'**
  String get checkinStress5;

  /// No description provided for @checkinTimeQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much time do you have today?'**
  String get checkinTimeQuestion;

  /// No description provided for @checkinMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String checkinMinutes(int minutes);

  /// No description provided for @checkinMinutesLong.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String checkinMinutesLong(int minutes);

  /// No description provided for @checkinBarrierQuestion.
  ///
  /// In en, this message translates to:
  /// **'Anything that could make today hard?'**
  String get checkinBarrierQuestion;

  /// No description provided for @checkinBarrierHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. A few words is plenty.'**
  String get checkinBarrierHint;

  /// No description provided for @checkinSkipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Skip question'**
  String get checkinSkipQuestion;

  /// No description provided for @checkinSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get checkinSkipForNow;

  /// No description provided for @checkinDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get checkinDone;

  /// No description provided for @checkinSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak instead'**
  String get checkinSpeak;

  /// No description provided for @checkinStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String checkinStepOf(int step, int total);

  /// No description provided for @checkinSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your check-in. Please try again.'**
  String get checkinSaveError;

  /// No description provided for @checkinContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get checkinContinue;

  /// No description provided for @homeTodayStepEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Today\'s one step'**
  String get homeTodayStepEyebrow;

  /// No description provided for @homeTodayStepTimed.
  ///
  /// In en, this message translates to:
  /// **'A step that fits in {minutes} minutes will appear here.'**
  String homeTodayStepTimed(int minutes);

  /// No description provided for @homeTodayStepUntimed.
  ///
  /// In en, this message translates to:
  /// **'A small step picked for you will appear here.'**
  String get homeTodayStepUntimed;

  /// No description provided for @homeTodayStepGentle.
  ///
  /// In en, this message translates to:
  /// **'A small, gentle step will appear here. Go easy on yourself today.'**
  String get homeTodayStepGentle;

  /// No description provided for @countryUsName.
  ///
  /// In en, this message translates to:
  /// **'the US'**
  String get countryUsName;

  /// No description provided for @homeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Live Well'**
  String get homeEyebrow;

  /// No description provided for @homeDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String homeDay(int day);

  /// No description provided for @homeDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of your journey'**
  String homeDayLabel(int day);

  /// No description provided for @homeCoachDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get homeCoachDefaultName;

  /// No description provided for @homeGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreetingNamed(String name);

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi there'**
  String get homeGreeting;

  /// No description provided for @homeBriefingSoon.
  ///
  /// In en, this message translates to:
  /// **'Briefing coming soon'**
  String get homeBriefingSoon;

  /// No description provided for @homeTodayStepBeforeCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in first. Then a small step picked for you will appear here.'**
  String get homeTodayStepBeforeCheckIn;

  /// No description provided for @homeStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeStepDone;

  /// No description provided for @homeStepSmaller.
  ///
  /// In en, this message translates to:
  /// **'Make it {minutes} min'**
  String homeStepSmaller(int minutes);

  /// No description provided for @homeStepSmallerLabel.
  ///
  /// In en, this message translates to:
  /// **'Make it a {minutes}-minute step'**
  String homeStepSmallerLabel(int minutes);

  /// No description provided for @homeStepDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'Done for today. Nice work.'**
  String get homeStepDoneMessage;

  /// No description provided for @homeStepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String homeStepMinutes(int minutes);

  /// No description provided for @homeStepGentleReason.
  ///
  /// In en, this message translates to:
  /// **'A gentle day. Go easy on yourself.'**
  String get homeStepGentleReason;

  /// No description provided for @homeQuickCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Quick check-in'**
  String get homeQuickCheckIn;

  /// No description provided for @homeQuickCheckInTime.
  ///
  /// In en, this message translates to:
  /// **'Takes 30s'**
  String get homeQuickCheckInTime;

  /// No description provided for @homeQuickCheckInLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick check-in. Takes about 30 seconds.'**
  String get homeQuickCheckInLabel;

  /// No description provided for @homeCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in today · Mood: {mood}'**
  String homeCheckedIn(String mood);

  /// No description provided for @homeMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Companion milestone'**
  String get homeMilestoneTitle;

  /// No description provided for @homeMilestonePhase.
  ///
  /// In en, this message translates to:
  /// **'Phase {phase} of {total}'**
  String homeMilestonePhase(int phase, int total);

  /// No description provided for @homeMilestoneHabits.
  ///
  /// In en, this message translates to:
  /// **'{kept} / {planned} habits kept'**
  String homeMilestoneHabits(int kept, int planned);

  /// No description provided for @homeMilestoneHabitsLabel.
  ///
  /// In en, this message translates to:
  /// **'{kept} of {planned} habits kept'**
  String homeMilestoneHabitsLabel(int kept, int planned);

  /// No description provided for @homeMilestoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your progress will show here once you start your first habit.'**
  String get homeMilestoneEmpty;

  /// No description provided for @planEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get planEyebrow;

  /// No description provided for @planNewHabit.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get planNewHabit;

  /// No description provided for @planFrameworkChip.
  ///
  /// In en, this message translates to:
  /// **'MY GOAL DO IT Framework · 8 Drivers'**
  String get planFrameworkChip;

  /// No description provided for @planFrameworkChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Open the MY GOAL DO IT framework'**
  String get planFrameworkChipLabel;

  /// No description provided for @planEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No habits yet'**
  String get planEmptyTitle;

  /// No description provided for @planEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your first small habit will show up here once your plan is ready.'**
  String get planEmptyBody;

  /// No description provided for @planStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planStatusDone;

  /// No description provided for @planStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get planStatusInProgress;

  /// No description provided for @planStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get planStatusScheduled;

  /// No description provided for @planCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed at {time}'**
  String planCompletedAt(String time);

  /// No description provided for @planTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {time}'**
  String planTarget(String time);

  /// No description provided for @planMicrostep.
  ///
  /// In en, this message translates to:
  /// **'Microstep: {step}'**
  String planMicrostep(String step);

  /// No description provided for @planMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String planMinutes(int minutes);

  /// No description provided for @planRoleMicrohabit.
  ///
  /// In en, this message translates to:
  /// **'Daily habit'**
  String get planRoleMicrohabit;

  /// No description provided for @planRoleSupporting.
  ///
  /// In en, this message translates to:
  /// **'Supporting habit'**
  String get planRoleSupporting;

  /// No description provided for @planMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" done'**
  String planMarkDone(String title);

  /// No description provided for @planFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan is full'**
  String get planFullTitle;

  /// No description provided for @planFullBody.
  ///
  /// In en, this message translates to:
  /// **'You have 1 daily habit and 2 supporting habits. That is plenty, so each one gets your attention. When one feels easy and automatic, you can swap it for something new.'**
  String get planFullBody;

  /// No description provided for @planAddSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Adding habits is coming soon'**
  String get planAddSoonTitle;

  /// No description provided for @planAddSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can add your own habits here. You can have 1 daily habit and up to 2 supporting habits.'**
  String get planAddSoonBody;

  /// No description provided for @planGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get planGotIt;

  /// No description provided for @planAffirmation1.
  ///
  /// In en, this message translates to:
  /// **'Focus on one small action today.'**
  String get planAffirmation1;

  /// No description provided for @planAffirmation2.
  ///
  /// In en, this message translates to:
  /// **'Small steps still count.'**
  String get planAffirmation2;

  /// No description provided for @planAffirmation3.
  ///
  /// In en, this message translates to:
  /// **'I don’t need perfect. I need my next step.'**
  String get planAffirmation3;

  /// No description provided for @planAffirmation4.
  ///
  /// In en, this message translates to:
  /// **'Every restart is progress.'**
  String get planAffirmation4;

  /// No description provided for @planAffirmation5.
  ///
  /// In en, this message translates to:
  /// **'Today, I choose one thing that helps me feel well.'**
  String get planAffirmation5;

  /// No description provided for @planAffirmationLabel.
  ///
  /// In en, this message translates to:
  /// **'Today’s thought'**
  String get planAffirmationLabel;

  /// No description provided for @frameworkTitle.
  ///
  /// In en, this message translates to:
  /// **'MY GOAL DO IT'**
  String get frameworkTitle;

  /// No description provided for @frameworkEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Framework'**
  String get frameworkEyebrow;

  /// No description provided for @frameworkIntro.
  ///
  /// In en, this message translates to:
  /// **'Dr. Gokula’s way of building habits that last. Each letter is one part of your plan.'**
  String get frameworkIntro;

  /// No description provided for @frameworkSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get frameworkSoon;

  /// No description provided for @frameworkOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get frameworkOpen;

  /// No description provided for @frameworkMindset.
  ///
  /// In en, this message translates to:
  /// **'Mindset'**
  String get frameworkMindset;

  /// No description provided for @frameworkMindsetBody.
  ///
  /// In en, this message translates to:
  /// **'A daily thought about who you are becoming.'**
  String get frameworkMindsetBody;

  /// No description provided for @frameworkWhy.
  ///
  /// In en, this message translates to:
  /// **'Your Why'**
  String get frameworkWhy;

  /// No description provided for @frameworkWhyBody.
  ///
  /// In en, this message translates to:
  /// **'The reason that keeps you going.'**
  String get frameworkWhyBody;

  /// No description provided for @frameworkWhyEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven’t written your Why yet.'**
  String get frameworkWhyEmpty;

  /// No description provided for @frameworkGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get frameworkGoals;

  /// No description provided for @frameworkGoalsBody.
  ///
  /// In en, this message translates to:
  /// **'Your 30-day goal and how it is going.'**
  String get frameworkGoalsBody;

  /// No description provided for @frameworkOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get frameworkOrganization;

  /// No description provided for @frameworkOrganizationBody.
  ///
  /// In en, this message translates to:
  /// **'When and where your habits happen.'**
  String get frameworkOrganizationBody;

  /// No description provided for @frameworkAccountability.
  ///
  /// In en, this message translates to:
  /// **'Accountability'**
  String get frameworkAccountability;

  /// No description provided for @frameworkAccountabilityBody.
  ///
  /// In en, this message translates to:
  /// **'Your coach checks in with you.'**
  String get frameworkAccountabilityBody;

  /// No description provided for @frameworkLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get frameworkLifestyle;

  /// No description provided for @frameworkLifestyleBody.
  ///
  /// In en, this message translates to:
  /// **'Food, movement, sleep, stress and connection.'**
  String get frameworkLifestyleBody;

  /// No description provided for @frameworkDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Discipline'**
  String get frameworkDiscipline;

  /// No description provided for @frameworkDisciplineBody.
  ///
  /// In en, this message translates to:
  /// **'Habits so small you can always do them.'**
  String get frameworkDisciplineBody;

  /// No description provided for @frameworkOptimism.
  ///
  /// In en, this message translates to:
  /// **'Optimism'**
  String get frameworkOptimism;

  /// No description provided for @frameworkOptimismBody.
  ///
  /// In en, this message translates to:
  /// **'Celebrating wins and kind restarts.'**
  String get frameworkOptimismBody;

  /// No description provided for @frameworkImplementation.
  ///
  /// In en, this message translates to:
  /// **'Implementation'**
  String get frameworkImplementation;

  /// No description provided for @frameworkImplementationBody.
  ///
  /// In en, this message translates to:
  /// **'One tap to start, timers and breathing.'**
  String get frameworkImplementationBody;

  /// No description provided for @frameworkTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get frameworkTracking;

  /// No description provided for @frameworkTrackingBody.
  ///
  /// In en, this message translates to:
  /// **'Check-ins, habits and how you feel over time.'**
  String get frameworkTrackingBody;

  /// No description provided for @trackEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Progression'**
  String get trackEyebrow;

  /// No description provided for @trackWeeklyWins.
  ///
  /// In en, this message translates to:
  /// **'Weekly wins'**
  String get trackWeeklyWins;

  /// No description provided for @trackWeeklyWinsSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly wins are coming soon'**
  String get trackWeeklyWinsSoonTitle;

  /// No description provided for @trackWeeklyWinsSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Every Sunday your coach will sum up your week: what went well, your check-ins and one small change for next week.'**
  String get trackWeeklyWinsSoonBody;

  /// No description provided for @trackGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get trackGotIt;

  /// No description provided for @trackStreakEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get trackStreakEyebrow;

  /// No description provided for @trackStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String trackStreakDays(int days);

  /// No description provided for @trackPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best'**
  String get trackPersonalBest;

  /// No description provided for @trackStreakEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your streak starts with your first habit. A missed day never resets it straight away: you get one rest day each week.'**
  String get trackStreakEmpty;

  /// No description provided for @trackDayMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get trackDayMon;

  /// No description provided for @trackDayTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get trackDayTue;

  /// No description provided for @trackDayWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get trackDayWed;

  /// No description provided for @trackDayThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get trackDayThu;

  /// No description provided for @trackDayFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get trackDayFri;

  /// No description provided for @trackDaySat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get trackDaySat;

  /// No description provided for @trackDaySun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get trackDaySun;

  /// No description provided for @trackDayDone.
  ///
  /// In en, this message translates to:
  /// **'{day}: done'**
  String trackDayDone(String day);

  /// No description provided for @trackDayRest.
  ///
  /// In en, this message translates to:
  /// **'{day}: rest day'**
  String trackDayRest(String day);

  /// No description provided for @trackDayRestart.
  ///
  /// In en, this message translates to:
  /// **'{day}: restart'**
  String trackDayRestart(String day);

  /// No description provided for @trackDayToday.
  ///
  /// In en, this message translates to:
  /// **'{day}: today'**
  String trackDayToday(String day);

  /// No description provided for @trackDayUpcoming.
  ///
  /// In en, this message translates to:
  /// **'{day}: coming up'**
  String trackDayUpcoming(String day);

  /// No description provided for @trackStreakLegend.
  ///
  /// In en, this message translates to:
  /// **'Rest days are part of the plan. One each week keeps your streak going.'**
  String get trackStreakLegend;

  /// No description provided for @trackCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'30-second daily check-in'**
  String get trackCheckInTitle;

  /// No description provided for @trackCheckInTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to log'**
  String get trackCheckInTap;

  /// No description provided for @trackEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get trackEnergy;

  /// No description provided for @trackSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get trackSleep;

  /// No description provided for @trackStress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get trackStress;

  /// No description provided for @trackMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get trackMood;

  /// No description provided for @trackNotLogged.
  ///
  /// In en, this message translates to:
  /// **'Not logged'**
  String get trackNotLogged;

  /// No description provided for @trackTileLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}: {value}. Tap to update your check-in.'**
  String trackTileLabel(String name, String value);

  /// No description provided for @trackTileEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}: not logged yet. Tap to check in.'**
  String trackTileEmptyLabel(String name);

  /// No description provided for @trackReflectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Evening reflection'**
  String get trackReflectionTitle;

  /// No description provided for @trackReflectionQuestion.
  ///
  /// In en, this message translates to:
  /// **'What went well today?'**
  String get trackReflectionQuestion;

  /// No description provided for @trackReflectionHint.
  ///
  /// In en, this message translates to:
  /// **'Speak or type your reflection…'**
  String get trackReflectionHint;

  /// No description provided for @trackReflectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get trackReflectionSave;

  /// No description provided for @trackReflectionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. Thanks for taking a moment.'**
  String get trackReflectionSaved;

  /// No description provided for @trackReflectionSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak instead'**
  String get trackReflectionSpeak;

  /// No description provided for @trackReflectionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get trackReflectionStop;

  /// No description provided for @trackReflectionError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your reflection. Please try again.'**
  String get trackReflectionError;

  /// No description provided for @trackReflectionNotSaved.
  ///
  /// In en, this message translates to:
  /// **'This was not saved.'**
  String get trackReflectionNotSaved;

  /// No description provided for @learnEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Approved knowledge'**
  String get learnEyebrow;

  /// No description provided for @learnPortalEyebrow.
  ///
  /// In en, this message translates to:
  /// **'From the Live Well Portal'**
  String get learnPortalEyebrow;

  /// No description provided for @learnPaidCourse.
  ///
  /// In en, this message translates to:
  /// **'Paid course'**
  String get learnPaidCourse;

  /// No description provided for @learnFreeLesson.
  ///
  /// In en, this message translates to:
  /// **'Free lesson'**
  String get learnFreeLesson;

  /// No description provided for @learnViewCourse.
  ///
  /// In en, this message translates to:
  /// **'View course'**
  String get learnViewCourse;

  /// No description provided for @learnNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get learnNotNow;

  /// No description provided for @learnPortalOpenError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the portal. Please try again.'**
  String get learnPortalOpenError;

  /// No description provided for @learnLibrary.
  ///
  /// In en, this message translates to:
  /// **'Curated library'**
  String get learnLibrary;

  /// No description provided for @learnViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all {count}'**
  String learnViewAll(int count);

  /// No description provided for @learnReadTime.
  ///
  /// In en, this message translates to:
  /// **'{minutes}-min read'**
  String learnReadTime(int minutes);

  /// No description provided for @learnLessonsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Lessons are on their way'**
  String get learnLessonsEmptyTitle;

  /// No description provided for @learnLessonsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Short lessons from Dr. Gokula\'s book will show up here once they are reviewed.'**
  String get learnLessonsEmptyBody;

  /// No description provided for @learnLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get learnLibraryTitle;

  /// No description provided for @careEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Direct support'**
  String get careEyebrow;

  /// No description provided for @careTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk to your coach'**
  String get careTitle;

  /// No description provided for @careStatusSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get careStatusSoon;

  /// No description provided for @careStatusAiVoice.
  ///
  /// In en, this message translates to:
  /// **'AI voice'**
  String get careStatusAiVoice;

  /// No description provided for @careStatusAiVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your coach speaks with an AI voice'**
  String get careStatusAiVoiceLabel;

  /// No description provided for @careHelpNow.
  ///
  /// In en, this message translates to:
  /// **'Get help now'**
  String get careHelpNow;

  /// No description provided for @careSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Your coach is coming soon'**
  String get careSoonTitle;

  /// No description provided for @careSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can talk or type to your coach here, any time of day. If you need help right now, tap \"Get help now\".'**
  String get careSoonBody;

  /// No description provided for @careNotSent.
  ///
  /// In en, this message translates to:
  /// **'Your coach isn’t available yet, so this message wasn’t sent. It stays on this screen only.'**
  String get careNotSent;

  /// No description provided for @careSources.
  ///
  /// In en, this message translates to:
  /// **'Sources: {sources}'**
  String careSources(String sources);

  /// No description provided for @careSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Where this comes from'**
  String get careSourcesTitle;

  /// No description provided for @careYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get careYou;

  /// No description provided for @careCoachSaid.
  ///
  /// In en, this message translates to:
  /// **'{coach} said'**
  String careCoachSaid(String coach);

  /// No description provided for @careDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Educational companion · Does not prescribe or change medication'**
  String get careDisclaimer;

  /// No description provided for @careTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get careTypeHint;

  /// No description provided for @careSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get careSend;

  /// No description provided for @careHoldToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get careHoldToTalk;

  /// No description provided for @careListening.
  ///
  /// In en, this message translates to:
  /// **'Listening… let go to stop'**
  String get careListening;

  /// No description provided for @careTalkHint.
  ///
  /// In en, this message translates to:
  /// **'Or tap once to start and again to stop'**
  String get careTalkHint;

  /// No description provided for @helpNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Get help now'**
  String get helpNowTitle;

  /// No description provided for @helpNowBody.
  ///
  /// In en, this message translates to:
  /// **'If you or someone else is in danger, call emergency services now. If you are struggling with how you feel, you can call or text a support line any time.'**
  String get helpNowBody;

  /// No description provided for @helpNowEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get helpNowEmergency;

  /// No description provided for @helpNowSupport.
  ///
  /// In en, this message translates to:
  /// **'Talk to someone'**
  String get helpNowSupport;

  /// No description provided for @signInOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get signInOrContinueWith;

  /// No description provided for @authErrorAccountExists.
  ///
  /// In en, this message translates to:
  /// **'You already have a Live Well account with this email. Sign in the way you did before (phone or email). Then we’ll offer to add this option to it.'**
  String get authErrorAccountExists;

  /// No description provided for @authLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {provider} to your account?'**
  String authLinkTitle(String provider);

  /// No description provided for @authLinkBody.
  ///
  /// In en, this message translates to:
  /// **'Next time you can sign in with {provider} or the way you just did. It’s the same account.'**
  String authLinkBody(String provider);

  /// No description provided for @authLinkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {provider}'**
  String authLinkAdd(String provider);

  /// No description provided for @authLinkNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get authLinkNotNow;

  /// No description provided for @authLinkDone.
  ///
  /// In en, this message translates to:
  /// **'{provider} is now added to your account.'**
  String authLinkDone(String provider);

  /// No description provided for @avatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your coach'**
  String get avatarTitle;

  /// No description provided for @avatarBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how your coach looks. You can change it any time.'**
  String get avatarBody;

  /// No description provided for @avatarPickLook.
  ///
  /// In en, this message translates to:
  /// **'Pick a starting look'**
  String get avatarPickLook;

  /// No description provided for @avatarLookWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get avatarLookWoman;

  /// No description provided for @avatarLookMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get avatarLookMan;

  /// No description provided for @avatarLookNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get avatarLookNeutral;

  /// No description provided for @avatarUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get avatarUseThis;

  /// No description provided for @avatarMakeCartoon.
  ///
  /// In en, this message translates to:
  /// **'Make a cartoon avatar'**
  String get avatarMakeCartoon;

  /// No description provided for @avatarUseSelfie.
  ///
  /// In en, this message translates to:
  /// **'Start from a selfie'**
  String get avatarUseSelfie;

  /// No description provided for @avatarSelfieNote.
  ///
  /// In en, this message translates to:
  /// **'Your photo stays on this phone and is deleted right after.'**
  String get avatarSelfieNote;

  /// No description provided for @avatarPhotorealSoon.
  ///
  /// In en, this message translates to:
  /// **'Real-looking video avatars: coming soon'**
  String get avatarPhotorealSoon;

  /// No description provided for @avatarSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip, use default'**
  String get avatarSkip;

  /// No description provided for @avatarPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Your coach’s avatar'**
  String get avatarPreviewLabel;

  /// No description provided for @avatarSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save your coach. Please try again.'**
  String get avatarSaveError;

  /// No description provided for @avatarCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Make your coach'**
  String get avatarCreatorTitle;

  /// No description provided for @avatarSuggested.
  ///
  /// In en, this message translates to:
  /// **'We suggested a skin tone and hair colour from your selfie. Please check them. Your photo has been deleted.'**
  String get avatarSuggested;

  /// No description provided for @avatarSelfieConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your selfie?'**
  String get avatarSelfieConsentTitle;

  /// No description provided for @avatarSelfieConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Live Well will look at one selfie on this phone to suggest a skin tone and hair colour for your cartoon coach. This uses your camera and reads features of your face. The photo is not uploaded and is deleted right after. You can change this any time in Settings > Consents.'**
  String get avatarSelfieConsentBody;

  /// No description provided for @avatarSelfieAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get avatarSelfieAllow;

  /// No description provided for @avatarSelfieNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get avatarSelfieNotNow;

  /// No description provided for @avatarSelfieFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t read that photo. You can pick the features yourself.'**
  String get avatarSelfieFailed;

  /// No description provided for @avatarSectionSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin tone'**
  String get avatarSectionSkin;

  /// No description provided for @avatarSectionHair.
  ///
  /// In en, this message translates to:
  /// **'Hair style'**
  String get avatarSectionHair;

  /// No description provided for @avatarSectionHairColour.
  ///
  /// In en, this message translates to:
  /// **'Hair colour'**
  String get avatarSectionHairColour;

  /// No description provided for @avatarSectionEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get avatarSectionEyes;

  /// No description provided for @avatarSectionGlasses.
  ///
  /// In en, this message translates to:
  /// **'Glasses'**
  String get avatarSectionGlasses;

  /// No description provided for @avatarSectionHeadCovering.
  ///
  /// In en, this message translates to:
  /// **'Head covering'**
  String get avatarSectionHeadCovering;

  /// No description provided for @avatarSectionClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get avatarSectionClothing;

  /// No description provided for @avatarSectionClothingColour.
  ///
  /// In en, this message translates to:
  /// **'Clothing colour'**
  String get avatarSectionClothingColour;

  /// No description provided for @avatarSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get avatarSectionBackground;

  /// No description provided for @avatarSkinTone.
  ///
  /// In en, this message translates to:
  /// **'Skin tone {n} of 10'**
  String avatarSkinTone(int n);

  /// No description provided for @avatarHairNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get avatarHairNone;

  /// No description provided for @avatarHairShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get avatarHairShort;

  /// No description provided for @avatarHairLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get avatarHairLong;

  /// No description provided for @avatarHairCurly.
  ///
  /// In en, this message translates to:
  /// **'Curly'**
  String get avatarHairCurly;

  /// No description provided for @avatarHairCoily.
  ///
  /// In en, this message translates to:
  /// **'Coily'**
  String get avatarHairCoily;

  /// No description provided for @avatarHairWavy.
  ///
  /// In en, this message translates to:
  /// **'Wavy'**
  String get avatarHairWavy;

  /// No description provided for @avatarHairBun.
  ///
  /// In en, this message translates to:
  /// **'Bun'**
  String get avatarHairBun;

  /// No description provided for @avatarHairBuzz.
  ///
  /// In en, this message translates to:
  /// **'Buzz cut'**
  String get avatarHairBuzz;

  /// No description provided for @avatarHairColourBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get avatarHairColourBlack;

  /// No description provided for @avatarHairColourDarkBrown.
  ///
  /// In en, this message translates to:
  /// **'Dark brown'**
  String get avatarHairColourDarkBrown;

  /// No description provided for @avatarHairColourBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get avatarHairColourBrown;

  /// No description provided for @avatarHairColourAuburn.
  ///
  /// In en, this message translates to:
  /// **'Auburn'**
  String get avatarHairColourAuburn;

  /// No description provided for @avatarHairColourBlonde.
  ///
  /// In en, this message translates to:
  /// **'Blonde'**
  String get avatarHairColourBlonde;

  /// No description provided for @avatarHairColourGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get avatarHairColourGrey;

  /// No description provided for @avatarHairColourWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get avatarHairColourWhite;

  /// No description provided for @avatarEyesRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get avatarEyesRound;

  /// No description provided for @avatarEyesAlmond.
  ///
  /// In en, this message translates to:
  /// **'Almond'**
  String get avatarEyesAlmond;

  /// No description provided for @avatarEyesSmiling.
  ///
  /// In en, this message translates to:
  /// **'Smiling'**
  String get avatarEyesSmiling;

  /// No description provided for @avatarGlassesNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get avatarGlassesNone;

  /// No description provided for @avatarGlassesRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get avatarGlassesRound;

  /// No description provided for @avatarGlassesSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get avatarGlassesSquare;

  /// No description provided for @avatarCoveringNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get avatarCoveringNone;

  /// No description provided for @avatarCoveringHijab.
  ///
  /// In en, this message translates to:
  /// **'Hijab'**
  String get avatarCoveringHijab;

  /// No description provided for @avatarCoveringTurban.
  ///
  /// In en, this message translates to:
  /// **'Turban'**
  String get avatarCoveringTurban;

  /// No description provided for @avatarCoveringKippah.
  ///
  /// In en, this message translates to:
  /// **'Kippah'**
  String get avatarCoveringKippah;

  /// No description provided for @avatarClothingCrew.
  ///
  /// In en, this message translates to:
  /// **'T-shirt'**
  String get avatarClothingCrew;

  /// No description provided for @avatarClothingCollar.
  ///
  /// In en, this message translates to:
  /// **'Collar'**
  String get avatarClothingCollar;

  /// No description provided for @avatarClothingCardigan.
  ///
  /// In en, this message translates to:
  /// **'Cardigan'**
  String get avatarClothingCardigan;

  /// No description provided for @avatarClothForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get avatarClothForest;

  /// No description provided for @avatarClothTerracotta.
  ///
  /// In en, this message translates to:
  /// **'Terracotta'**
  String get avatarClothTerracotta;

  /// No description provided for @avatarClothSage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get avatarClothSage;

  /// No description provided for @avatarClothNavy.
  ///
  /// In en, this message translates to:
  /// **'Navy'**
  String get avatarClothNavy;

  /// No description provided for @avatarClothMustard.
  ///
  /// In en, this message translates to:
  /// **'Mustard'**
  String get avatarClothMustard;

  /// No description provided for @avatarClothPlum.
  ///
  /// In en, this message translates to:
  /// **'Plum'**
  String get avatarClothPlum;

  /// No description provided for @avatarBgSage.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get avatarBgSage;

  /// No description provided for @avatarBgPeach.
  ///
  /// In en, this message translates to:
  /// **'Peach'**
  String get avatarBgPeach;

  /// No description provided for @avatarBgCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get avatarBgCream;

  /// No description provided for @avatarBgSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get avatarBgSky;

  /// No description provided for @avatarBgLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get avatarBgLavender;

  /// No description provided for @avatarBgSunshine.
  ///
  /// In en, this message translates to:
  /// **'Sunshine'**
  String get avatarBgSunshine;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your coach’s voice'**
  String get voiceTitle;

  /// No description provided for @voiceAiLabel.
  ///
  /// In en, this message translates to:
  /// **'AI voice'**
  String get voiceAiLabel;

  /// No description provided for @voiceAiLabelLong.
  ///
  /// In en, this message translates to:
  /// **'This is an AI voice'**
  String get voiceAiLabelLong;

  /// No description provided for @voiceGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, I’m your Live Well coach.'**
  String voiceGreetingNamed(String name);

  /// No description provided for @voiceGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, I’m your Live Well coach.'**
  String get voiceGreeting;

  /// No description provided for @voicePlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get voicePlayAgain;

  /// No description provided for @voiceSoundsGood.
  ///
  /// In en, this message translates to:
  /// **'Sounds good'**
  String get voiceSoundsGood;

  /// No description provided for @voiceChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another voice'**
  String get voiceChooseAnother;

  /// No description provided for @voiceSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip, use default'**
  String get voiceSkip;

  /// No description provided for @voiceOwnTitle.
  ///
  /// In en, this message translates to:
  /// **'Use my own voice'**
  String get voiceOwnTitle;

  /// No description provided for @voiceOwnSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get voiceOwnSoon;

  /// No description provided for @voiceOwnBody.
  ///
  /// In en, this message translates to:
  /// **'Recording your own voice will need your consent, a short live recording in the app and a check that it’s really you. It isn’t available yet.'**
  String get voiceOwnBody;

  /// No description provided for @voiceGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get voiceGotIt;

  /// No description provided for @voiceLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice library'**
  String get voiceLibraryTitle;

  /// No description provided for @voiceStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get voiceStyle;

  /// No description provided for @voiceStyleCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get voiceStyleCalm;

  /// No description provided for @voiceStyleEnergetic.
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get voiceStyleEnergetic;

  /// No description provided for @voiceSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get voiceSpeed;

  /// No description provided for @voiceSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed}x'**
  String voiceSpeedValue(String speed);

  /// No description provided for @voicePreview.
  ///
  /// In en, this message translates to:
  /// **'Play {name}'**
  String voicePreview(String name);

  /// No description provided for @voiceUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use this voice'**
  String get voiceUseThis;

  /// No description provided for @voiceAccentUs.
  ///
  /// In en, this message translates to:
  /// **'US English'**
  String get voiceAccentUs;

  /// No description provided for @voiceAccentUk.
  ///
  /// In en, this message translates to:
  /// **'UK English'**
  String get voiceAccentUk;

  /// No description provided for @voiceSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save your coach’s voice. Please try again.'**
  String get voiceSaveError;

  /// No description provided for @voiceNameWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get voiceNameWarm;

  /// No description provided for @voiceNameBright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get voiceNameBright;

  /// No description provided for @voiceNameSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get voiceNameSteady;

  /// No description provided for @voiceNameDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get voiceNameDeep;

  /// No description provided for @voiceNameGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get voiceNameGentle;

  /// No description provided for @voiceNameClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get voiceNameClear;

  /// No description provided for @onbCheckinTitle.
  ///
  /// In en, this message translates to:
  /// **'First, a quick check-in'**
  String get onbCheckinTitle;

  /// No description provided for @onbCheckinBody.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today? It takes about 30 seconds and helps your coach plan a kind first week.'**
  String get onbCheckinBody;

  /// No description provided for @onbCheckinStart.
  ///
  /// In en, this message translates to:
  /// **'Start check-in'**
  String get onbCheckinStart;

  /// No description provided for @onbCheckinSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip the check-in'**
  String get onbCheckinSkip;

  /// No description provided for @focusTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to work on this week?'**
  String get focusTitle;

  /// No description provided for @focusBody.
  ///
  /// In en, this message translates to:
  /// **'Pick one. You can add a second if you like.'**
  String get focusBody;

  /// No description provided for @focusMoveMore.
  ///
  /// In en, this message translates to:
  /// **'Move more'**
  String get focusMoveMore;

  /// No description provided for @focusSleepBetter.
  ///
  /// In en, this message translates to:
  /// **'Sleep better'**
  String get focusSleepBetter;

  /// No description provided for @focusEatBetter.
  ///
  /// In en, this message translates to:
  /// **'Eat better'**
  String get focusEatBetter;

  /// No description provided for @focusLessStress.
  ///
  /// In en, this message translates to:
  /// **'Feel less stressed'**
  String get focusLessStress;

  /// No description provided for @focusMoreEnergy.
  ///
  /// In en, this message translates to:
  /// **'More energy'**
  String get focusMoreEnergy;

  /// No description provided for @focusHealthyRoutine.
  ///
  /// In en, this message translates to:
  /// **'Build a healthy routine'**
  String get focusHealthyRoutine;

  /// No description provided for @focusFirst.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get focusFirst;

  /// No description provided for @focusSecond.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get focusSecond;

  /// No description provided for @focusFirstLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, first choice'**
  String focusFirstLabel(String name);

  /// No description provided for @focusSecondLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, second choice'**
  String focusSecondLabel(String name);

  /// No description provided for @focusFull.
  ///
  /// In en, this message translates to:
  /// **'You’ve picked two. Tap one to remove it first.'**
  String get focusFull;

  /// No description provided for @focusContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get focusContinue;

  /// No description provided for @focusSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save your choice. Please try again.'**
  String get focusSaveError;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Before we plan any movement'**
  String get activityTitle;

  /// No description provided for @activityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you have chest pain, fainting or severe breathlessness, or has a doctor or nurse told you to limit your activity?'**
  String get activityQuestion;

  /// No description provided for @activityYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get activityYes;

  /// No description provided for @activityNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get activityNo;

  /// No description provided for @activityLimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk to your clinician first'**
  String get activityLimitedTitle;

  /// No description provided for @activityLimitedBody.
  ///
  /// In en, this message translates to:
  /// **'Please check with your doctor or nurse before starting new exercise. For now, your plan will focus on sleep, stress, food and routine, with no exercise. You can change this later in Settings.'**
  String get activityLimitedBody;

  /// No description provided for @activityLimitedNow.
  ///
  /// In en, this message translates to:
  /// **'If you have chest pain, fainting or trouble breathing right now, get help now.'**
  String get activityLimitedNow;

  /// No description provided for @activityContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get activityContinue;

  /// No description provided for @planPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your 7 days'**
  String get planPreviewTitle;

  /// No description provided for @planPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'One small step a day, sized to the time you have. You can change the times.'**
  String get planPreviewBody;

  /// No description provided for @planTouchpoints.
  ///
  /// In en, this message translates to:
  /// **'Your 3 daily moments'**
  String get planTouchpoints;

  /// No description provided for @planMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning greeting'**
  String get planMorning;

  /// No description provided for @planMidday.
  ///
  /// In en, this message translates to:
  /// **'Midday nudge'**
  String get planMidday;

  /// No description provided for @planEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening reflection'**
  String get planEvening;

  /// No description provided for @planTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} at {time}. Tap to change.'**
  String planTimeLabel(String name, String time);

  /// No description provided for @planQuietHours.
  ///
  /// In en, this message translates to:
  /// **'That’s during quiet hours ({start} to {end}). Please pick another time.'**
  String planQuietHours(String start, String end);

  /// No description provided for @planAlsoThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Also this week'**
  String get planAlsoThisWeek;

  /// No description provided for @planDay.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String planDay(int n);

  /// No description provided for @planSmaller.
  ///
  /// In en, this message translates to:
  /// **'Short on time? {step}'**
  String planSmaller(String step);

  /// No description provided for @planGentle.
  ///
  /// In en, this message translates to:
  /// **'A gentle start today.'**
  String get planGentle;

  /// No description provided for @planStart.
  ///
  /// In en, this message translates to:
  /// **'Start my plan'**
  String get planStart;

  /// No description provided for @planNotReady.
  ///
  /// In en, this message translates to:
  /// **'Your starter plan is being reviewed by our care team. Your coach will set it up soon.'**
  String get planNotReady;

  /// No description provided for @planNotReadyContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get planNotReadyContinue;

  /// No description provided for @planReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Get gentle reminders?'**
  String get planReminderTitle;

  /// No description provided for @planReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Live Well can remind you three times a day: a morning hello, a midday nudge for your step and an evening check-in. Reminders never show health details, and you can turn them off any time. Your plan works without them.'**
  String get planReminderBody;

  /// No description provided for @planReminderAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow reminders'**
  String get planReminderAllow;

  /// No description provided for @planReminderNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get planReminderNotNow;

  /// No description provided for @planSaveError.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save your plan. Please try again.'**
  String get planSaveError;

  /// No description provided for @reminderChannel.
  ///
  /// In en, this message translates to:
  /// **'Daily plan'**
  String get reminderChannel;

  /// No description provided for @reminderGreetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get reminderGreetingTitle;

  /// No description provided for @reminderGreetingBody.
  ///
  /// In en, this message translates to:
  /// **'Your coach has a hello and today’s small step for you.'**
  String get reminderGreetingBody;

  /// No description provided for @reminderNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for your small step'**
  String get reminderNudgeTitle;

  /// No description provided for @reminderNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Open Live Well when you’re ready.'**
  String get reminderNudgeBody;

  /// No description provided for @reminderReflectionTitle.
  ///
  /// In en, this message translates to:
  /// **'A moment to look back'**
  String get reminderReflectionTitle;

  /// No description provided for @reminderReflectionBody.
  ///
  /// In en, this message translates to:
  /// **'What went well today?'**
  String get reminderReflectionBody;

  /// No description provided for @authErrorLastMethod.
  ///
  /// In en, this message translates to:
  /// **'This is your only way to sign in, so it can’t be removed.'**
  String get authErrorLastMethod;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileOpen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileOpen;

  /// No description provided for @coachAvatarLabel.
  ///
  /// In en, this message translates to:
  /// **'Your coach'**
  String get coachAvatarLabel;

  /// No description provided for @profileSignedInWith.
  ///
  /// In en, this message translates to:
  /// **'Signed in with'**
  String get profileSignedInWith;

  /// No description provided for @profileMethodEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileMethodEmail;

  /// No description provided for @profileMethodPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileMethodPhone;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile picture'**
  String get profileChangePhoto;

  /// No description provided for @profileTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profileTakePhoto;

  /// No description provided for @profileChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profileChoosePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove picture'**
  String get profileRemovePhoto;

  /// No description provided for @profilePhotoNote.
  ///
  /// In en, this message translates to:
  /// **'Your picture is kept on this phone only for now.'**
  String get profilePhotoNote;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileEditName;

  /// No description provided for @profileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your first name'**
  String get profileNameHint;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get profileLinked;

  /// No description provided for @profileLink.
  ///
  /// In en, this message translates to:
  /// **'Add {provider}'**
  String profileLink(String provider);

  /// No description provided for @profileUnlink.
  ///
  /// In en, this message translates to:
  /// **'Remove {provider}'**
  String profileUnlink(String provider);

  /// No description provided for @profileLinkPhoneSoon.
  ///
  /// In en, this message translates to:
  /// **'Add a phone number: coming soon'**
  String get profileLinkPhoneSoon;

  /// No description provided for @profileLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOut;

  /// No description provided for @profileSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get profileSwitch;

  /// No description provided for @profileLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get profileLogOutTitle;

  /// No description provided for @profileLogOutBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll clear your data from this phone and stop reminders. Everything stays safe in your account.'**
  String get profileLogOutBody;

  /// No description provided for @profileMyCoach.
  ///
  /// In en, this message translates to:
  /// **'My coach'**
  String get profileMyCoach;

  /// No description provided for @profileChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get profileChangeAvatar;

  /// No description provided for @profileChangeVoice.
  ///
  /// In en, this message translates to:
  /// **'Change voice'**
  String get profileChangeVoice;

  /// No description provided for @profileCoachName.
  ///
  /// In en, this message translates to:
  /// **'Coach name'**
  String get profileCoachName;

  /// No description provided for @profileCoachNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Maya'**
  String get profileCoachNameHint;

  /// No description provided for @profileCoachNameError.
  ///
  /// In en, this message translates to:
  /// **'Use 1 to 20 letters.'**
  String get profileCoachNameError;

  /// No description provided for @profileAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearance;

  /// No description provided for @profileThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileThemeDark;

  /// No description provided for @profileTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get profileTextSize;

  /// No description provided for @profileTextNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get profileTextNormal;

  /// No description provided for @profileTextLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get profileTextLarger;

  /// No description provided for @profileTextLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get profileTextLargest;

  /// No description provided for @profileDailyPlan.
  ///
  /// In en, this message translates to:
  /// **'Daily plan'**
  String get profileDailyPlan;

  /// No description provided for @profileQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get profileQuietHours;

  /// No description provided for @profileQuietValue.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String profileQuietValue(String start, String end);

  /// No description provided for @profileQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get profileQuietStart;

  /// No description provided for @profileQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get profileQuietEnd;

  /// No description provided for @profileReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get profileReminders;

  /// No description provided for @profileRemindersOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off. You can turn them on in Privacy & consents.'**
  String get profileRemindersOff;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get profilePrivacy;

  /// No description provided for @profileConsents.
  ///
  /// In en, this message translates to:
  /// **'Privacy & consents'**
  String get profileConsents;

  /// No description provided for @profileMemory.
  ///
  /// In en, this message translates to:
  /// **'What my coach remembers'**
  String get profileMemory;

  /// No description provided for @profileExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get profileExport;

  /// No description provided for @profileSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get profileSoon;

  /// No description provided for @profileDeleteAvatar.
  ///
  /// In en, this message translates to:
  /// **'Delete my avatar'**
  String get profileDeleteAvatar;

  /// No description provided for @profileDeleteVoice.
  ///
  /// In en, this message translates to:
  /// **'Delete my voice'**
  String get profileDeleteVoice;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAvatarBody.
  ///
  /// In en, this message translates to:
  /// **'Your coach’s avatar will be deleted. Your coach will use the default look.'**
  String get profileDeleteAvatarBody;

  /// No description provided for @profileDeleteVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Your coach’s voice choice will be deleted. Your coach will use the default voice.'**
  String get profileDeleteVoiceBody;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account and everything in it: your Why, check-ins, plans and reflections. It can’t be undone.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDeleteConfirm;

  /// No description provided for @profileDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted.'**
  String get profileDeleted;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t delete that right now. Please try again later.'**
  String get profileDeleteFailed;

  /// No description provided for @profileHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & about'**
  String get profileHelp;

  /// No description provided for @profileTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get profileTerms;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String profileVersion(String version);

  /// No description provided for @profileDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get profileDeveloper;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get profileSaved;

  /// No description provided for @homeGreetingMorningNamed.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}!'**
  String homeGreetingMorningNamed(String name);

  /// No description provided for @homeGreetingAfternoonNamed.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}!'**
  String homeGreetingAfternoonNamed(String name);

  /// No description provided for @homeGreetingEveningNamed.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}!'**
  String homeGreetingEveningNamed(String name);

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning!'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon!'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening!'**
  String get homeGreetingEvening;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready for a healthier, happier you?'**
  String get homeSubtitle;

  /// No description provided for @homeBubbleNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}! Let\'s make today a good day.'**
  String homeBubbleNamed(String name);

  /// No description provided for @homeBubble.
  ///
  /// In en, this message translates to:
  /// **'Hi! Let\'s make today a good day.'**
  String get homeBubble;

  /// No description provided for @homeBubbleGentleNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}. Let\'s keep today gentle.'**
  String homeBubbleGentleNamed(String name);

  /// No description provided for @homeBubbleGentle.
  ///
  /// In en, this message translates to:
  /// **'Hi. Let\'s keep today gentle.'**
  String get homeBubbleGentle;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Small steps. Brighter days.'**
  String get homeTagline;

  /// No description provided for @homeNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Next Step'**
  String get homeNextStepTitle;

  /// No description provided for @homeNextStepOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s next step: {title}. Opens Done and a smaller option.'**
  String homeNextStepOpenLabel(String title);

  /// No description provided for @homeStepDoneShort.
  ///
  /// In en, this message translates to:
  /// **'Done for today'**
  String get homeStepDoneShort;

  /// No description provided for @homeCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Check-in'**
  String get homeCheckInTitle;

  /// No description provided for @homeTileMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get homeTileMood;

  /// No description provided for @homeTileEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get homeTileEnergy;

  /// No description provided for @homeTileSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get homeTileSleep;

  /// No description provided for @homeTileStress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get homeTileStress;

  /// No description provided for @homeTileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap to log'**
  String get homeTileEmpty;

  /// No description provided for @homeTileSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get homeTileSkipped;

  /// No description provided for @homeTileLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}: {value}. Opens the check-in.'**
  String homeTileLabel(String name, String value);

  /// No description provided for @homeStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 Day Streak} other{{days} Day Streak}}'**
  String homeStreakTitle(int days);

  /// No description provided for @homeStreakKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get homeStreakKeepGoing;

  /// No description provided for @homeStreakEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your streak starts with your first step.'**
  String get homeStreakEmpty;

  /// No description provided for @checkinResponseGentleLowMood.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling me. Low days happen, and they pass. Let\'s keep today gentle.'**
  String get checkinResponseGentleLowMood;

  /// No description provided for @checkinResponseGentleStress.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling me. Stress is high today, so let\'s keep things calm and simple.'**
  String get checkinResponseGentleStress;

  /// No description provided for @checkinResponseGentleBoth.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling me. Feeling low and stressed is a lot. Let\'s go slowly today.'**
  String get checkinResponseGentleBoth;

  /// No description provided for @homeStepGentleLowMood.
  ///
  /// In en, this message translates to:
  /// **'Feeling low? A small step still counts.'**
  String get homeStepGentleLowMood;

  /// No description provided for @homeStepGentleStress.
  ///
  /// In en, this message translates to:
  /// **'A calm, easy step for a stressful day.'**
  String get homeStepGentleStress;

  /// No description provided for @homeStepGentleBoth.
  ///
  /// In en, this message translates to:
  /// **'Go easy on yourself. The smallest step is plenty.'**
  String get homeStepGentleBoth;

  /// No description provided for @homeNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should your coach call you?'**
  String get homeNameTitle;

  /// No description provided for @homeNameSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get homeNameSave;

  /// No description provided for @homeNameNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get homeNameNotNow;

  /// No description provided for @homeNameError.
  ///
  /// In en, this message translates to:
  /// **'Please use letters only (up to 30).'**
  String get homeNameError;

  /// No description provided for @profileAddName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileAddName;

  /// No description provided for @planMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Live Well Map'**
  String get planMapTitle;

  /// No description provided for @planMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'8 Drivers for a Balanced Life'**
  String get planMapSubtitle;

  /// No description provided for @planMapCenter.
  ///
  /// In en, this message translates to:
  /// **'Live Well'**
  String get planMapCenter;

  /// No description provided for @planMapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Take your 10-minute check to fill your map.'**
  String get planMapEmpty;

  /// No description provided for @planMapDriverLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}: {percent}% in the last 30 days. Opens details.'**
  String planMapDriverLabel(String name, int percent);

  /// No description provided for @planMapDriverLabelEmpty.
  ///
  /// In en, this message translates to:
  /// **'{name}. Opens details.'**
  String planMapDriverLabelEmpty(String name);

  /// No description provided for @planDriverBody.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of this driver’s steps done in the last 30 days.'**
  String planDriverBody(int percent);

  /// No description provided for @planDriverBodyEmpty.
  ///
  /// In en, this message translates to:
  /// **'This part of your map fills in after your 10-minute check.'**
  String get planDriverBodyEmpty;

  /// No description provided for @planGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Your 30-Day Goal'**
  String get planGoalTitle;

  /// No description provided for @planGoalEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get planGoalEdit;

  /// No description provided for @planGoalEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit your 30-day goal'**
  String get planGoalEditLabel;

  /// No description provided for @planGoalDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String planGoalDay(int day, int total);

  /// No description provided for @planGoalPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String planGoalPercent(int percent);

  /// No description provided for @planGoalProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}, {percent}% done'**
  String planGoalProgressLabel(int day, int total, int percent);

  /// No description provided for @planGoalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your 30-day goal is set after your 10-minute check.'**
  String get planGoalEmpty;

  /// No description provided for @planGoalEditSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Changing your goal is coming soon'**
  String get planGoalEditSoonTitle;

  /// No description provided for @planGoalEditSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can change your 30-day goal here. Your coach will help you keep it small and doable.'**
  String get planGoalEditSoonBody;

  /// No description provided for @planHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Microhabits'**
  String get planHabitsTitle;

  /// No description provided for @planHabitMenu.
  ///
  /// In en, this message translates to:
  /// **'More options for {title}'**
  String planHabitMenu(String title);

  /// No description provided for @planHabitAbout.
  ///
  /// In en, this message translates to:
  /// **'About this habit'**
  String get planHabitAbout;

  /// No description provided for @planHabitSmaller.
  ///
  /// In en, this message translates to:
  /// **'Make it smaller'**
  String get planHabitSmaller;

  /// No description provided for @planWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get planWeekTitle;

  /// No description provided for @planWeekOpen.
  ///
  /// In en, this message translates to:
  /// **'Open your week'**
  String get planWeekOpen;

  /// No description provided for @planWeekEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your plan’s days will show here.'**
  String get planWeekEmpty;

  /// No description provided for @planWeekToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planWeekToday;

  /// No description provided for @planFrameworkRow.
  ///
  /// In en, this message translates to:
  /// **'MY GOAL DO IT framework'**
  String get planFrameworkRow;

  /// No description provided for @planFrameworkRowBody.
  ///
  /// In en, this message translates to:
  /// **'Your 10 building blocks, one letter at a time'**
  String get planFrameworkRowBody;

  /// No description provided for @trackPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get trackPeriodWeek;

  /// No description provided for @trackPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get trackPeriodMonth;

  /// No description provided for @trackPeriodQuarter.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get trackPeriodQuarter;

  /// No description provided for @trackPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Showing {period}. Opens the choices.'**
  String trackPeriodLabel(String period);

  /// No description provided for @trackSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get trackSteps;

  /// No description provided for @trackStepsOf.
  ///
  /// In en, this message translates to:
  /// **'of {goal}'**
  String trackStepsOf(String goal);

  /// No description provided for @trackConnectHealth.
  ///
  /// In en, this message translates to:
  /// **'Connect Health'**
  String get trackConnectHealth;

  /// No description provided for @trackConnectHealthLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps: connect Apple Health or Health Connect. Opens details.'**
  String get trackConnectHealthLabel;

  /// No description provided for @trackHealthSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting Health is coming soon'**
  String get trackHealthSoonTitle;

  /// No description provided for @trackHealthSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can connect Apple Health or Health Connect. Your steps and sleep hours will show here, and only if you choose to share them.'**
  String get trackHealthSoonBody;

  /// No description provided for @trackSleepHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String trackSleepHours(int hours, int minutes);

  /// No description provided for @trackFromCheckIns.
  ///
  /// In en, this message translates to:
  /// **'From your check-ins'**
  String get trackFromCheckIns;

  /// No description provided for @trackOutOf5.
  ///
  /// In en, this message translates to:
  /// **'{value} / 5'**
  String trackOutOf5(String value);

  /// No description provided for @trackNoCheckIns.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get trackNoCheckIns;

  /// No description provided for @trackCardLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}: {value}. {detail}'**
  String trackCardLabel(String name, String value, String detail);

  /// No description provided for @trackProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get trackProgressTitle;

  /// No description provided for @trackThisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get trackThisWeekLabel;

  /// No description provided for @trackChipHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get trackChipHabits;

  /// No description provided for @trackChartBarLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}: {value}'**
  String trackChartBarLabel(String day, String value);

  /// No description provided for @trackChartBarEmpty.
  ///
  /// In en, this message translates to:
  /// **'{day}: nothing logged'**
  String trackChartBarEmpty(String day);

  /// No description provided for @trackChartSelected.
  ///
  /// In en, this message translates to:
  /// **'{label}. Selected.'**
  String trackChartSelected(String label);

  /// No description provided for @trackChartStepsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Connect Health to see your steps here.'**
  String get trackChartStepsEmpty;

  /// No description provided for @trackChartHabitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your habits will show here once you start one.'**
  String get trackChartHabitsEmpty;

  /// No description provided for @trackChartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Check in to see your week here.'**
  String get trackChartEmpty;

  /// No description provided for @trackHabitsKept.
  ///
  /// In en, this message translates to:
  /// **'{count} kept'**
  String trackHabitsKept(int count);

  /// No description provided for @trackWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Reflection'**
  String get trackWeeklyTitle;

  /// No description provided for @trackWeeklyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How was your week?'**
  String get trackWeeklyQuestion;

  /// No description provided for @trackWeeklyBody.
  ///
  /// In en, this message translates to:
  /// **'Celebrate your wins and set intentions for next week.'**
  String get trackWeeklyBody;

  /// No description provided for @trackWeeklyLabel.
  ///
  /// In en, this message translates to:
  /// **'How was your week? Opens your weekly reflection.'**
  String get trackWeeklyLabel;

  /// No description provided for @learnSearch.
  ///
  /// In en, this message translates to:
  /// **'Search lessons'**
  String get learnSearch;

  /// No description provided for @learnSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search lessons and audio'**
  String get learnSearchHint;

  /// No description provided for @learnSearchStart.
  ///
  /// In en, this message translates to:
  /// **'Search by title or topic.'**
  String get learnSearchStart;

  /// No description provided for @learnSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”.'**
  String learnSearchEmpty(String query);

  /// No description provided for @learnFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get learnFilterAll;

  /// No description provided for @learnFilterLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get learnFilterLessons;

  /// No description provided for @learnFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get learnFilterAudio;

  /// No description provided for @learnFilterPrograms.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get learnFilterPrograms;

  /// No description provided for @learnContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get learnContinueTitle;

  /// No description provided for @learnKindLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get learnKindLesson;

  /// No description provided for @learnKindAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get learnKindAudio;

  /// No description provided for @learnMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String learnMinutes(int minutes);

  /// No description provided for @learnPercentDone.
  ///
  /// In en, this message translates to:
  /// **'{percent}% done'**
  String learnPercentDone(int percent);

  /// No description provided for @learnContinueLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}. {kind}, {minutes} minutes, {percent}% done. Opens it.'**
  String learnContinueLabel(
    String title,
    String kind,
    int minutes,
    int percent,
  );

  /// No description provided for @learnFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured Lessons'**
  String get learnFeatured;

  /// No description provided for @learnSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get learnSeeAll;

  /// No description provided for @learnPopularAudio.
  ///
  /// In en, this message translates to:
  /// **'Popular Audio Sessions'**
  String get learnPopularAudio;

  /// No description provided for @learnPlay.
  ///
  /// In en, this message translates to:
  /// **'Play {title}'**
  String learnPlay(String title);

  /// No description provided for @learnOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'{title}. {minutes} minutes. Opens it.'**
  String learnOpenLabel(String title, int minutes);

  /// No description provided for @learnOpenLabelNoTime.
  ///
  /// In en, this message translates to:
  /// **'{title}. Opens it.'**
  String learnOpenLabelNoTime(String title);

  /// No description provided for @learnOpenSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lessons open here soon'**
  String get learnOpenSoonTitle;

  /// No description provided for @learnOpenSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can read the full lesson here, and save it to read offline.'**
  String get learnOpenSoonBody;

  /// No description provided for @learnAudioSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio sessions are coming soon'**
  String get learnAudioSoonTitle;

  /// No description provided for @learnAudioSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you can listen here, and download sessions to listen offline.'**
  String get learnAudioSoonBody;

  /// No description provided for @learnAudioEmpty.
  ///
  /// In en, this message translates to:
  /// **'Audio sessions will show here once they are reviewed.'**
  String get learnAudioEmpty;

  /// No description provided for @learnProgramsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No programs right now'**
  String get learnProgramsEmptyTitle;

  /// No description provided for @learnProgramsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Courses from the Live Well Portal show here when one fits you.'**
  String get learnProgramsEmptyBody;

  /// No description provided for @learnGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get learnGotIt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
