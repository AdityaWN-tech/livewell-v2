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
  String get homeTitle => 'Home';

  @override
  String get startupErrorTitle => 'We couldn\'t start Live Well';

  @override
  String get startupErrorBody => 'Please check your connection and try again.';

  @override
  String get startupErrorRetry => 'Try again';

  @override
  String get devDesignTokens => 'Design tokens';
}
