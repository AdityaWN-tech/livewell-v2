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

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day starts here'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your morning briefing, one next step and a quick check-in will show up here.'**
  String get homeEmptyBody;

  /// No description provided for @planEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get planEmptyTitle;

  /// No description provided for @planEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your Live Well Map, your 30-day goal and your daily habits will live here.'**
  String get planEmptyBody;

  /// No description provided for @trackEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get trackEmptyTitle;

  /// No description provided for @trackEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins, habits and the numbers you log will show here as simple charts.'**
  String get trackEmptyBody;

  /// No description provided for @learnEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn something small'**
  String get learnEmptyTitle;

  /// No description provided for @learnEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Short lessons from the Live Well book, audio and breathing sessions will be here.'**
  String get learnEmptyBody;

  /// No description provided for @careEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Care and support'**
  String get careEmptyTitle;

  /// No description provided for @careEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Talk with your coach, see what it remembers, and find safety and clinician help here.'**
  String get careEmptyBody;

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
  /// **'Create your account'**
  String get signInTitle;

  /// No description provided for @signInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign-in options are being added next.'**
  String get signInComingSoon;
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
