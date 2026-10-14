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
  /// **'Use your phone number, email or Google. If you already use the Live Well portal, use the same phone number or email.'**
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
  /// **'A little'**
  String get checkinStress2;

  /// No description provided for @checkinStress3.
  ///
  /// In en, this message translates to:
  /// **'Some'**
  String get checkinStress3;

  /// No description provided for @checkinStress4.
  ///
  /// In en, this message translates to:
  /// **'A lot'**
  String get checkinStress4;

  /// No description provided for @checkinStress5.
  ///
  /// In en, this message translates to:
  /// **'Very'**
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
