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
}
