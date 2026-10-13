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
