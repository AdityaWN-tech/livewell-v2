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
  String get devIllustrations => 'Illustrations';

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
      'Use your phone number, email, Google or Apple. If you already use the Live Well portal, use the same phone number or email.';

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

  @override
  String get safetyEmergencyTitle => 'This could be an emergency';

  @override
  String get safetyEmergencyBody =>
      'Please call for emergency help now. If you can, unlock your door and ask someone to stay with you.';

  @override
  String safetyCallNumber(String number) {
    return 'Call $number';
  }

  @override
  String safetyCallNumberIn(String number, String country) {
    return 'Call $number in $country';
  }

  @override
  String get safetyCrisisTitle => 'You don\'t have to face this alone';

  @override
  String get safetyCrisisBody =>
      'If you\'re thinking about suicide or hurting yourself, please reach out to someone right now. It\'s free and confidential, and they\'re there day and night.';

  @override
  String safetyCrisisCall(String name, String number) {
    return 'Call $name: $number';
  }

  @override
  String safetyCrisisText(String number) {
    return 'Text $number';
  }

  @override
  String get safetyCrisisDanger =>
      'If you\'re in danger right now, call emergency services.';

  @override
  String get safetyEdTitle => 'Let\'s take care of you first';

  @override
  String get safetyEdBody =>
      'It sounds like food or your body may feel hard right now. Live Well won\'t help with very low-calorie or fast weight-loss plans. A doctor or an eating-disorder specialist can support you, and you deserve that support.';

  @override
  String get safetyMedTitle =>
      'Medicine changes are for you and your prescriber';

  @override
  String get safetyMedBody =>
      'Please don\'t start, stop or change any medicine or supplement without talking to the doctor who prescribed it. Live Well can help with daily habits alongside your treatment.';

  @override
  String get safetyComplexTitle => 'Check with your clinician first';

  @override
  String get safetyComplexBody =>
      'Pregnancy and some health conditions change what\'s safe for you. Please talk to your doctor or midwife before changing how you eat or move.';

  @override
  String get safetyBack => 'Go back';

  @override
  String get safetyChangeIt => 'Change it';

  @override
  String get safetySaveAnyway => 'Save my Why';

  @override
  String get countryIndiaName => 'India';

  @override
  String safetyCallFailed(String number) {
    return 'We couldn\'t start the call. Please dial $number.';
  }

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String get settingsDeveloperBody =>
      'Tools for building the app. Only in the dev build.';

  @override
  String get checkinResponseHigh =>
      'Love that energy. Let\'s use it well today.';

  @override
  String get checkinResponseSteady =>
      'Thanks for checking in. One small step is plenty today.';

  @override
  String get checkinResponseGentle =>
      'Thanks for telling me. Let\'s keep today gentle.';

  @override
  String checkinMoodQuestionNamed(String name) {
    return 'Hi $name, how are you feeling today?';
  }

  @override
  String get checkinMoodQuestion => 'Hi, how are you feeling today?';

  @override
  String get checkinMood1 => 'Very low';

  @override
  String get checkinMood2 => 'Low';

  @override
  String get checkinMood3 => 'Okay';

  @override
  String get checkinMood4 => 'Good';

  @override
  String get checkinMood5 => 'Great';

  @override
  String get checkinEnergyQuestion => 'How is your energy?';

  @override
  String get checkinEnergy1 => 'Very low';

  @override
  String get checkinEnergy2 => 'Low';

  @override
  String get checkinEnergy3 => 'Okay';

  @override
  String get checkinEnergy4 => 'Good';

  @override
  String get checkinEnergy5 => 'High';

  @override
  String get checkinSleepQuestion => 'How did you sleep last night?';

  @override
  String get checkinSleep1 => 'Very badly';

  @override
  String get checkinSleep2 => 'Badly';

  @override
  String get checkinSleep3 => 'Okay';

  @override
  String get checkinSleep4 => 'Well';

  @override
  String get checkinSleep5 => 'Very well';

  @override
  String get checkinStressQuestion => 'How stressed do you feel?';

  @override
  String get checkinStress1 => 'Not at all';

  @override
  String get checkinStress2 => 'Low';

  @override
  String get checkinStress3 => 'Moderate';

  @override
  String get checkinStress4 => 'High';

  @override
  String get checkinStress5 => 'Very high';

  @override
  String get checkinTimeQuestion => 'How much time do you have today?';

  @override
  String checkinMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String checkinMinutesLong(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get checkinBarrierQuestion => 'Anything that could make today hard?';

  @override
  String get checkinBarrierHint => 'Optional. A few words is plenty.';

  @override
  String get checkinSkipQuestion => 'Skip question';

  @override
  String get checkinSkipForNow => 'Skip for now';

  @override
  String get checkinDone => 'Done';

  @override
  String get checkinSpeak => 'Speak instead';

  @override
  String checkinStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get checkinSaveError =>
      'We couldn\'t save your check-in. Please try again.';

  @override
  String get checkinContinue => 'Continue';

  @override
  String get homeTodayStepEyebrow => 'Today\'s one step';

  @override
  String homeTodayStepTimed(int minutes) {
    return 'A step that fits in $minutes minutes will appear here.';
  }

  @override
  String get homeTodayStepUntimed =>
      'A small step picked for you will appear here.';

  @override
  String get homeTodayStepGentle =>
      'A small, gentle step will appear here. Go easy on yourself today.';

  @override
  String get countryUsName => 'the US';

  @override
  String get homeEyebrow => 'Live Well';

  @override
  String homeDay(int day) {
    return 'Day $day';
  }

  @override
  String homeDayLabel(int day) {
    return 'Day $day of your journey';
  }

  @override
  String get homeCoachDefaultName => 'Coach';

  @override
  String homeGreetingNamed(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeGreeting => 'Hi there';

  @override
  String get homeBriefingSoon => 'Briefing coming soon';

  @override
  String get homeTodayStepBeforeCheckIn =>
      'Check in first. Then a small step picked for you will appear here.';

  @override
  String get homeStepDone => 'Done';

  @override
  String homeStepSmaller(int minutes) {
    return 'Make it $minutes min';
  }

  @override
  String homeStepSmallerLabel(int minutes) {
    return 'Make it a $minutes-minute step';
  }

  @override
  String get homeStepDoneMessage => 'Done for today. Nice work.';

  @override
  String homeStepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get homeStepGentleReason => 'A gentle day. Go easy on yourself.';

  @override
  String get homeQuickCheckIn => 'Quick check-in';

  @override
  String get homeQuickCheckInTime => 'Takes 30s';

  @override
  String get homeQuickCheckInLabel => 'Quick check-in. Takes about 30 seconds.';

  @override
  String homeCheckedIn(String mood) {
    return 'Checked in today · Mood: $mood';
  }

  @override
  String get homeMilestoneTitle => 'Companion milestone';

  @override
  String homeMilestonePhase(int phase, int total) {
    return 'Phase $phase of $total';
  }

  @override
  String homeMilestoneHabits(int kept, int planned) {
    return '$kept / $planned habits kept';
  }

  @override
  String homeMilestoneHabitsLabel(int kept, int planned) {
    return '$kept of $planned habits kept';
  }

  @override
  String get homeMilestoneEmpty =>
      'Your progress will show here once you start your first habit.';

  @override
  String get planEyebrow => 'Schedule';

  @override
  String get planNewHabit => 'New habit';

  @override
  String get planFrameworkChip => 'MY GOAL DO IT Framework · 8 Drivers';

  @override
  String get planFrameworkChipLabel => 'Open the MY GOAL DO IT framework';

  @override
  String get planEmptyTitle => 'No habits yet';

  @override
  String get planEmptyBody =>
      'Your first small habit will show up here once your plan is ready.';

  @override
  String get planStatusDone => 'Done';

  @override
  String get planStatusInProgress => 'In progress';

  @override
  String get planStatusScheduled => 'Scheduled';

  @override
  String planCompletedAt(String time) {
    return 'Completed at $time';
  }

  @override
  String planTarget(String time) {
    return 'Target: $time';
  }

  @override
  String planMicrostep(String step) {
    return 'Microstep: $step';
  }

  @override
  String planMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get planRoleMicrohabit => 'Daily habit';

  @override
  String get planRoleSupporting => 'Supporting habit';

  @override
  String planMarkDone(String title) {
    return 'Mark \"$title\" done';
  }

  @override
  String get planFullTitle => 'Your plan is full';

  @override
  String get planFullBody =>
      'You have 1 daily habit and 2 supporting habits. That is plenty, so each one gets your attention. When one feels easy and automatic, you can swap it for something new.';

  @override
  String get planAddSoonTitle => 'Adding habits is coming soon';

  @override
  String get planAddSoonBody =>
      'Soon you can add your own habits here. You can have 1 daily habit and up to 2 supporting habits.';

  @override
  String get planGotIt => 'Got it';

  @override
  String get planAffirmation1 => 'Focus on one small action today.';

  @override
  String get planAffirmation2 => 'Small steps still count.';

  @override
  String get planAffirmation3 => 'I don’t need perfect. I need my next step.';

  @override
  String get planAffirmation4 => 'Every restart is progress.';

  @override
  String get planAffirmation5 =>
      'Today, I choose one thing that helps me feel well.';

  @override
  String get planAffirmationLabel => 'Today’s thought';

  @override
  String get frameworkTitle => 'MY GOAL DO IT';

  @override
  String get frameworkEyebrow => 'Framework';

  @override
  String get frameworkIntro =>
      'Dr. Gokula’s way of building habits that last. Each letter is one part of your plan.';

  @override
  String get frameworkSoon => 'Coming soon';

  @override
  String get frameworkOpen => 'Open';

  @override
  String get frameworkMindset => 'Mindset';

  @override
  String get frameworkMindsetBody =>
      'A daily thought about who you are becoming.';

  @override
  String get frameworkWhy => 'Your Why';

  @override
  String get frameworkWhyBody => 'The reason that keeps you going.';

  @override
  String get frameworkWhyEmpty => 'You haven’t written your Why yet.';

  @override
  String get frameworkGoals => 'Goals';

  @override
  String get frameworkGoalsBody => 'Your 30-day goal and how it is going.';

  @override
  String get frameworkOrganization => 'Organization';

  @override
  String get frameworkOrganizationBody => 'When and where your habits happen.';

  @override
  String get frameworkAccountability => 'Accountability';

  @override
  String get frameworkAccountabilityBody => 'Your coach checks in with you.';

  @override
  String get frameworkLifestyle => 'Lifestyle';

  @override
  String get frameworkLifestyleBody =>
      'Food, movement, sleep, stress and connection.';

  @override
  String get frameworkDiscipline => 'Discipline';

  @override
  String get frameworkDisciplineBody =>
      'Habits so small you can always do them.';

  @override
  String get frameworkOptimism => 'Optimism';

  @override
  String get frameworkOptimismBody => 'Celebrating wins and kind restarts.';

  @override
  String get frameworkImplementation => 'Implementation';

  @override
  String get frameworkImplementationBody =>
      'One tap to start, timers and breathing.';

  @override
  String get frameworkTracking => 'Tracking';

  @override
  String get frameworkTrackingBody =>
      'Check-ins, habits and how you feel over time.';

  @override
  String get trackEyebrow => 'Progression';

  @override
  String get trackWeeklyWins => 'Weekly wins';

  @override
  String get trackWeeklyWinsSoonTitle => 'Weekly wins are coming soon';

  @override
  String get trackWeeklyWinsSoonBody =>
      'Every Sunday your coach will sum up your week: what went well, your check-ins and one small change for next week.';

  @override
  String get trackGotIt => 'Got it';

  @override
  String get trackStreakEyebrow => 'Consistency';

  @override
  String trackStreakDays(int days) {
    return '$days-day streak';
  }

  @override
  String get trackPersonalBest => 'Personal best';

  @override
  String get trackStreakEmpty =>
      'Your streak starts with your first habit. A missed day never resets it straight away: you get one rest day each week.';

  @override
  String get trackDayMon => 'M';

  @override
  String get trackDayTue => 'T';

  @override
  String get trackDayWed => 'W';

  @override
  String get trackDayThu => 'T';

  @override
  String get trackDayFri => 'F';

  @override
  String get trackDaySat => 'S';

  @override
  String get trackDaySun => 'S';

  @override
  String trackDayDone(String day) {
    return '$day: done';
  }

  @override
  String trackDayRest(String day) {
    return '$day: rest day';
  }

  @override
  String trackDayRestart(String day) {
    return '$day: restart';
  }

  @override
  String trackDayToday(String day) {
    return '$day: today';
  }

  @override
  String trackDayUpcoming(String day) {
    return '$day: coming up';
  }

  @override
  String get trackStreakLegend =>
      'Rest days are part of the plan. One each week keeps your streak going.';

  @override
  String get trackCheckInTitle => '30-second daily check-in';

  @override
  String get trackCheckInTap => 'Tap to log';

  @override
  String get trackEnergy => 'Energy';

  @override
  String get trackSleep => 'Sleep';

  @override
  String get trackStress => 'Stress';

  @override
  String get trackMood => 'Mood';

  @override
  String get trackNotLogged => 'Not logged';

  @override
  String trackTileLabel(String name, String value) {
    return '$name: $value. Tap to update your check-in.';
  }

  @override
  String trackTileEmptyLabel(String name) {
    return '$name: not logged yet. Tap to check in.';
  }

  @override
  String get trackReflectionTitle => 'Evening reflection';

  @override
  String get trackReflectionQuestion => 'What went well today?';

  @override
  String get trackReflectionHint => 'Speak or type your reflection…';

  @override
  String get trackReflectionSave => 'Save';

  @override
  String get trackReflectionSaved => 'Saved. Thanks for taking a moment.';

  @override
  String get trackReflectionSpeak => 'Speak instead';

  @override
  String get trackReflectionStop => 'Stop listening';

  @override
  String get trackReflectionError =>
      'We couldn\'t save your reflection. Please try again.';

  @override
  String get trackReflectionNotSaved => 'This was not saved.';

  @override
  String get learnEyebrow => 'Approved knowledge';

  @override
  String get learnPortalEyebrow => 'From the Live Well Portal';

  @override
  String get learnPaidCourse => 'Paid course';

  @override
  String get learnFreeLesson => 'Free lesson';

  @override
  String get learnViewCourse => 'View course';

  @override
  String get learnNotNow => 'Not now';

  @override
  String get learnPortalOpenError =>
      'We couldn\'t open the portal. Please try again.';

  @override
  String get learnLibrary => 'Curated library';

  @override
  String learnViewAll(int count) {
    return 'View all $count';
  }

  @override
  String learnReadTime(int minutes) {
    return '$minutes-min read';
  }

  @override
  String get learnLessonsEmptyTitle => 'Lessons are on their way';

  @override
  String get learnLessonsEmptyBody =>
      'Short lessons from Dr. Gokula\'s book will show up here once they are reviewed.';

  @override
  String get learnLibraryTitle => 'Library';

  @override
  String get careEyebrow => 'Direct support';

  @override
  String get careTitle => 'Talk to your coach';

  @override
  String get careStatusSoon => 'Coming soon';

  @override
  String get careStatusAiVoice => 'AI voice';

  @override
  String get careStatusAiVoiceLabel => 'Your coach speaks with an AI voice';

  @override
  String get careHelpNow => 'Get help now';

  @override
  String get careSoonTitle => 'Your coach is coming soon';

  @override
  String get careSoonBody =>
      'Soon you can talk or type to your coach here, any time of day. If you need help right now, tap \"Get help now\".';

  @override
  String get careNotSent =>
      'Your coach isn’t available yet, so this message wasn’t sent. It stays on this screen only.';

  @override
  String careSources(String sources) {
    return 'Sources: $sources';
  }

  @override
  String get careSourcesTitle => 'Where this comes from';

  @override
  String get careYou => 'You';

  @override
  String careCoachSaid(String coach) {
    return '$coach said';
  }

  @override
  String get careDisclaimer =>
      'Educational companion · Does not prescribe or change medication';

  @override
  String get careTypeHint => 'Type a message';

  @override
  String get careSend => 'Send';

  @override
  String get careHoldToTalk => 'Hold to talk';

  @override
  String get careListening => 'Listening… let go to stop';

  @override
  String get careTalkHint => 'Or tap once to start and again to stop';

  @override
  String get helpNowTitle => 'Get help now';

  @override
  String get helpNowBody =>
      'If you or someone else is in danger, call emergency services now. If you are struggling with how you feel, you can call or text a support line any time.';

  @override
  String get helpNowEmergency => 'Emergency';

  @override
  String get helpNowSupport => 'Talk to someone';

  @override
  String get signInOrContinueWith => 'or continue with';

  @override
  String get authErrorAccountExists =>
      'You already have a Live Well account with this email. Sign in the way you did before (phone or email). Then we’ll offer to add this option to it.';

  @override
  String authLinkTitle(String provider) {
    return 'Add $provider to your account?';
  }

  @override
  String authLinkBody(String provider) {
    return 'Next time you can sign in with $provider or the way you just did. It’s the same account.';
  }

  @override
  String authLinkAdd(String provider) {
    return 'Add $provider';
  }

  @override
  String get authLinkNotNow => 'Not now';

  @override
  String authLinkDone(String provider) {
    return '$provider is now added to your account.';
  }

  @override
  String get avatarTitle => 'Create your coach';

  @override
  String get avatarBody =>
      'Choose how your coach looks. You can change it any time.';

  @override
  String get avatarPickLook => 'Pick a starting look';

  @override
  String get avatarLookWoman => 'Woman';

  @override
  String get avatarLookMan => 'Man';

  @override
  String get avatarLookNeutral => 'Neutral';

  @override
  String get avatarUseThis => 'Use this';

  @override
  String get avatarMakeCartoon => 'Make a cartoon avatar';

  @override
  String get avatarUseSelfie => 'Start from a selfie';

  @override
  String get avatarSelfieNote =>
      'Your photo stays on this phone and is deleted right after.';

  @override
  String get avatarPhotorealSoon => 'Real-looking video avatars: coming soon';

  @override
  String get avatarSkip => 'Skip, use default';

  @override
  String get avatarPreviewLabel => 'Your coach’s avatar';

  @override
  String get avatarSaveError =>
      'We couldn’t save your coach. Please try again.';

  @override
  String get avatarCreatorTitle => 'Make your coach';

  @override
  String get avatarSuggested =>
      'We suggested a skin tone and hair colour from your selfie. Please check them. Your photo has been deleted.';

  @override
  String get avatarSelfieConsentTitle => 'Use your selfie?';

  @override
  String get avatarSelfieConsentBody =>
      'Live Well will look at one selfie on this phone to suggest a skin tone and hair colour for your cartoon coach. This uses your camera and reads features of your face. The photo is not uploaded and is deleted right after. You can change this any time in Settings > Consents.';

  @override
  String get avatarSelfieAllow => 'Allow';

  @override
  String get avatarSelfieNotNow => 'Not now';

  @override
  String get avatarSelfieFailed =>
      'We couldn’t read that photo. You can pick the features yourself.';

  @override
  String get avatarSectionSkin => 'Skin tone';

  @override
  String get avatarSectionHair => 'Hair style';

  @override
  String get avatarSectionHairColour => 'Hair colour';

  @override
  String get avatarSectionEyes => 'Eyes';

  @override
  String get avatarSectionGlasses => 'Glasses';

  @override
  String get avatarSectionHeadCovering => 'Head covering';

  @override
  String get avatarSectionClothing => 'Clothing';

  @override
  String get avatarSectionClothingColour => 'Clothing colour';

  @override
  String get avatarSectionBackground => 'Background';

  @override
  String avatarSkinTone(int n) {
    return 'Skin tone $n of 10';
  }

  @override
  String get avatarHairNone => 'None';

  @override
  String get avatarHairShort => 'Short';

  @override
  String get avatarHairLong => 'Long';

  @override
  String get avatarHairCurly => 'Curly';

  @override
  String get avatarHairCoily => 'Coily';

  @override
  String get avatarHairWavy => 'Wavy';

  @override
  String get avatarHairBun => 'Bun';

  @override
  String get avatarHairBuzz => 'Buzz cut';

  @override
  String get avatarHairColourBlack => 'Black';

  @override
  String get avatarHairColourDarkBrown => 'Dark brown';

  @override
  String get avatarHairColourBrown => 'Brown';

  @override
  String get avatarHairColourAuburn => 'Auburn';

  @override
  String get avatarHairColourBlonde => 'Blonde';

  @override
  String get avatarHairColourGrey => 'Grey';

  @override
  String get avatarHairColourWhite => 'White';

  @override
  String get avatarEyesRound => 'Round';

  @override
  String get avatarEyesAlmond => 'Almond';

  @override
  String get avatarEyesSmiling => 'Smiling';

  @override
  String get avatarGlassesNone => 'None';

  @override
  String get avatarGlassesRound => 'Round';

  @override
  String get avatarGlassesSquare => 'Square';

  @override
  String get avatarCoveringNone => 'None';

  @override
  String get avatarCoveringHijab => 'Hijab';

  @override
  String get avatarCoveringTurban => 'Turban';

  @override
  String get avatarCoveringKippah => 'Kippah';

  @override
  String get avatarClothingCrew => 'T-shirt';

  @override
  String get avatarClothingCollar => 'Collar';

  @override
  String get avatarClothingCardigan => 'Cardigan';

  @override
  String get avatarClothForest => 'Forest';

  @override
  String get avatarClothTerracotta => 'Terracotta';

  @override
  String get avatarClothSage => 'Sage';

  @override
  String get avatarClothNavy => 'Navy';

  @override
  String get avatarClothMustard => 'Mustard';

  @override
  String get avatarClothPlum => 'Plum';

  @override
  String get avatarBgSage => 'Mint';

  @override
  String get avatarBgPeach => 'Peach';

  @override
  String get avatarBgCream => 'Cream';

  @override
  String get avatarBgSky => 'Sky';

  @override
  String get avatarBgLavender => 'Lavender';

  @override
  String get avatarBgSunshine => 'Sunshine';

  @override
  String get voiceTitle => 'Choose your coach’s voice';

  @override
  String get voiceAiLabel => 'AI voice';

  @override
  String get voiceAiLabelLong => 'This is an AI voice';

  @override
  String voiceGreetingNamed(String name) {
    return 'Hi $name, I’m your Live Well coach.';
  }

  @override
  String get voiceGreeting => 'Hi, I’m your Live Well coach.';

  @override
  String get voicePlayAgain => 'Play again';

  @override
  String get voiceSoundsGood => 'Sounds good';

  @override
  String get voiceChooseAnother => 'Choose another voice';

  @override
  String get voiceSkip => 'Skip, use default';

  @override
  String get voiceOwnTitle => 'Use my own voice';

  @override
  String get voiceOwnSoon => 'Coming soon';

  @override
  String get voiceOwnBody =>
      'Recording your own voice will need your consent, a short live recording in the app and a check that it’s really you. It isn’t available yet.';

  @override
  String get voiceGotIt => 'Got it';

  @override
  String get voiceLibraryTitle => 'Voice library';

  @override
  String get voiceStyle => 'Style';

  @override
  String get voiceStyleCalm => 'Calm';

  @override
  String get voiceStyleEnergetic => 'Energetic';

  @override
  String get voiceSpeed => 'Speed';

  @override
  String voiceSpeedValue(String speed) {
    return '${speed}x';
  }

  @override
  String voicePreview(String name) {
    return 'Play $name';
  }

  @override
  String get voiceUseThis => 'Use this voice';

  @override
  String get voiceAccentUs => 'US English';

  @override
  String get voiceAccentUk => 'UK English';

  @override
  String get voiceSaveError =>
      'We couldn’t save your coach’s voice. Please try again.';

  @override
  String get voiceNameWarm => 'Warm';

  @override
  String get voiceNameBright => 'Bright';

  @override
  String get voiceNameSteady => 'Steady';

  @override
  String get voiceNameDeep => 'Deep';

  @override
  String get voiceNameGentle => 'Gentle';

  @override
  String get voiceNameClear => 'Clear';

  @override
  String get onbCheckinTitle => 'First, a quick check-in';

  @override
  String get onbCheckinBody =>
      'How are you feeling today? It takes about 30 seconds and helps your coach plan a kind first week.';

  @override
  String get onbCheckinStart => 'Start check-in';

  @override
  String get onbCheckinSkip => 'Skip the check-in';

  @override
  String get focusTitle => 'What would you like to work on this week?';

  @override
  String get focusBody => 'Pick one. You can add a second if you like.';

  @override
  String get focusMoveMore => 'Move more';

  @override
  String get focusSleepBetter => 'Sleep better';

  @override
  String get focusEatBetter => 'Eat better';

  @override
  String get focusLessStress => 'Feel less stressed';

  @override
  String get focusMoreEnergy => 'More energy';

  @override
  String get focusHealthyRoutine => 'Build a healthy routine';

  @override
  String get focusFirst => '1st';

  @override
  String get focusSecond => '2nd';

  @override
  String focusFirstLabel(String name) {
    return '$name, first choice';
  }

  @override
  String focusSecondLabel(String name) {
    return '$name, second choice';
  }

  @override
  String get focusFull => 'You’ve picked two. Tap one to remove it first.';

  @override
  String get focusContinue => 'Continue';

  @override
  String get focusSaveError =>
      'We couldn’t save your choice. Please try again.';

  @override
  String get activityTitle => 'Before we plan any movement';

  @override
  String get activityQuestion =>
      'Do you have chest pain, fainting or severe breathlessness, or has a doctor or nurse told you to limit your activity?';

  @override
  String get activityYes => 'Yes';

  @override
  String get activityNo => 'No';

  @override
  String get activityLimitedTitle => 'Talk to your clinician first';

  @override
  String get activityLimitedBody =>
      'Please check with your doctor or nurse before starting new exercise. For now, your plan will focus on sleep, stress, food and routine, with no exercise. You can change this later in Settings.';

  @override
  String get activityLimitedNow =>
      'If you have chest pain, fainting or trouble breathing right now, get help now.';

  @override
  String get activityContinue => 'Continue';

  @override
  String get planPreviewTitle => 'Your 7 days';

  @override
  String get planPreviewBody =>
      'One small step a day, sized to the time you have. You can change the times.';

  @override
  String get planTouchpoints => 'Your 3 daily moments';

  @override
  String get planMorning => 'Morning greeting';

  @override
  String get planMidday => 'Midday nudge';

  @override
  String get planEvening => 'Evening reflection';

  @override
  String planTimeLabel(String name, String time) {
    return '$name at $time. Tap to change.';
  }

  @override
  String planQuietHours(String start, String end) {
    return 'That’s during quiet hours ($start to $end). Please pick another time.';
  }

  @override
  String get planAlsoThisWeek => 'Also this week';

  @override
  String planDay(int n) {
    return 'Day $n';
  }

  @override
  String planSmaller(String step) {
    return 'Short on time? $step';
  }

  @override
  String get planGentle => 'A gentle start today.';

  @override
  String get planStart => 'Start my plan';

  @override
  String get planNotReady =>
      'Your starter plan is being reviewed by our care team. Your coach will set it up soon.';

  @override
  String get planNotReadyContinue => 'Continue';

  @override
  String get planReminderTitle => 'Get gentle reminders?';

  @override
  String get planReminderBody =>
      'Live Well can remind you three times a day: a morning hello, a midday nudge for your step and an evening check-in. Reminders never show health details, and you can turn them off any time. Your plan works without them.';

  @override
  String get planReminderAllow => 'Allow reminders';

  @override
  String get planReminderNotNow => 'Not now';

  @override
  String get planSaveError => 'We couldn’t save your plan. Please try again.';

  @override
  String get reminderChannel => 'Daily plan';

  @override
  String get reminderGreetingTitle => 'Good morning';

  @override
  String get reminderGreetingBody =>
      'Your coach has a hello and today’s small step for you.';

  @override
  String get reminderNudgeTitle => 'Time for your small step';

  @override
  String get reminderNudgeBody => 'Open Live Well when you’re ready.';

  @override
  String get reminderReflectionTitle => 'A moment to look back';

  @override
  String get reminderReflectionBody => 'What went well today?';

  @override
  String get authErrorLastMethod =>
      'This is your only way to sign in, so it can’t be removed.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileOpen => 'Profile';

  @override
  String get coachAvatarLabel => 'Your coach';

  @override
  String get profileSignedInWith => 'Signed in with';

  @override
  String get profileMethodEmail => 'Email';

  @override
  String get profileMethodPhone => 'Phone';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileChangePhoto => 'Change profile picture';

  @override
  String get profileTakePhoto => 'Take a photo';

  @override
  String get profileChoosePhoto => 'Choose from gallery';

  @override
  String get profileRemovePhoto => 'Remove picture';

  @override
  String get profilePhotoNote =>
      'Your picture is kept on this phone only for now.';

  @override
  String get profileEditName => 'Name';

  @override
  String get profileNameHint => 'Your first name';

  @override
  String get profileSave => 'Save';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileLinked => 'Linked';

  @override
  String profileLink(String provider) {
    return 'Add $provider';
  }

  @override
  String profileUnlink(String provider) {
    return 'Remove $provider';
  }

  @override
  String get profileLinkPhoneSoon => 'Add a phone number: coming soon';

  @override
  String get profileLogOut => 'Log out';

  @override
  String get profileSwitch => 'Switch account';

  @override
  String get profileLogOutTitle => 'Log out?';

  @override
  String get profileLogOutBody =>
      'We’ll clear your data from this phone and stop reminders. Everything stays safe in your account.';

  @override
  String get profileMyCoach => 'My coach';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileChangeVoice => 'Change voice';

  @override
  String get profileCoachName => 'Coach name';

  @override
  String get profileCoachNameHint => 'For example, Maya';

  @override
  String get profileCoachNameError => 'Use 1 to 20 letters.';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileThemeSystem => 'System';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileTextSize => 'Text size';

  @override
  String get profileTextNormal => 'Normal';

  @override
  String get profileTextLarger => 'Larger';

  @override
  String get profileTextLargest => 'Largest';

  @override
  String get profileDailyPlan => 'Daily plan';

  @override
  String get profileQuietHours => 'Quiet hours';

  @override
  String profileQuietValue(String start, String end) {
    return '$start to $end';
  }

  @override
  String get profileQuietStart => 'Quiet hours start';

  @override
  String get profileQuietEnd => 'Quiet hours end';

  @override
  String get profileReminders => 'Reminders';

  @override
  String get profileRemindersOff =>
      'Reminders are off. You can turn them on in Privacy & consents.';

  @override
  String get profilePrivacy => 'Privacy & data';

  @override
  String get profileConsents => 'Privacy & consents';

  @override
  String get profileMemory => 'What my coach remembers';

  @override
  String get profileExport => 'Export my data';

  @override
  String get profileSoon => 'Coming soon';

  @override
  String get profileDeleteAvatar => 'Delete my avatar';

  @override
  String get profileDeleteVoice => 'Delete my voice';

  @override
  String get profileDeleteAccount => 'Delete my account';

  @override
  String get profileDeleteAvatarBody =>
      'Your coach’s avatar will be deleted. Your coach will use the default look.';

  @override
  String get profileDeleteVoiceBody =>
      'Your coach’s voice choice will be deleted. Your coach will use the default voice.';

  @override
  String get profileDeleteAccountBody =>
      'This deletes your account and everything in it: your Why, check-ins, plans and reflections. It can’t be undone.';

  @override
  String get profileDeleteConfirm => 'Delete';

  @override
  String get profileDeleted => 'Deleted.';

  @override
  String get profileDeleteFailed =>
      'We couldn’t delete that right now. Please try again later.';

  @override
  String get profileHelp => 'Help & about';

  @override
  String get profileTerms => 'Terms of use';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String get profileDeveloper => 'Developer';

  @override
  String get profileSaved => 'Saved.';

  @override
  String homeGreetingMorningNamed(String name) {
    return 'Good morning, $name!';
  }

  @override
  String homeGreetingAfternoonNamed(String name) {
    return 'Good afternoon, $name!';
  }

  @override
  String homeGreetingEveningNamed(String name) {
    return 'Good evening, $name!';
  }

  @override
  String get homeGreetingMorning => 'Good morning!';

  @override
  String get homeGreetingAfternoon => 'Good afternoon!';

  @override
  String get homeGreetingEvening => 'Good evening!';

  @override
  String get homeSubtitle => 'Ready for a healthier, happier you?';

  @override
  String homeBubbleNamed(String name) {
    return 'Hi, $name! Let\'s make today a good day.';
  }

  @override
  String get homeBubble => 'Hi! Let\'s make today a good day.';

  @override
  String homeBubbleGentleNamed(String name) {
    return 'Hi, $name. Let\'s keep today gentle.';
  }

  @override
  String get homeBubbleGentle => 'Hi. Let\'s keep today gentle.';

  @override
  String get homeTagline => 'Small steps. Brighter days.';

  @override
  String get homeNextStepTitle => 'Today\'s Next Step';

  @override
  String homeNextStepOpenLabel(String title) {
    return 'Today\'s next step: $title. Opens Done and a smaller option.';
  }

  @override
  String get homeStepDoneShort => 'Done for today';

  @override
  String get homeCheckInTitle => 'Quick Check-in';

  @override
  String get homeTileMood => 'Mood';

  @override
  String get homeTileEnergy => 'Energy';

  @override
  String get homeTileSleep => 'Sleep';

  @override
  String get homeTileStress => 'Stress';

  @override
  String get homeTileEmpty => 'Tap to log';

  @override
  String get homeTileSkipped => 'Skipped';

  @override
  String homeTileLabel(String name, String value) {
    return '$name: $value. Opens the check-in.';
  }

  @override
  String homeStreakTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Day Streak',
      one: '1 Day Streak',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakKeepGoing => 'Keep going!';

  @override
  String get homeStreakEmpty => 'Your streak starts with your first step.';

  @override
  String get checkinResponseGentleLowMood =>
      'Thanks for telling me. Low days happen, and they pass. Let\'s keep today gentle.';

  @override
  String get checkinResponseGentleStress =>
      'Thanks for telling me. Stress is high today, so let\'s keep things calm and simple.';

  @override
  String get checkinResponseGentleBoth =>
      'Thanks for telling me. Feeling low and stressed is a lot. Let\'s go slowly today.';

  @override
  String get homeStepGentleLowMood => 'Feeling low? A small step still counts.';

  @override
  String get homeStepGentleStress => 'A calm, easy step for a stressful day.';

  @override
  String get homeStepGentleBoth =>
      'Go easy on yourself. The smallest step is plenty.';

  @override
  String get homeNameTitle => 'What should your coach call you?';

  @override
  String get homeNameSave => 'Save';

  @override
  String get homeNameNotNow => 'Not now';

  @override
  String get homeNameError => 'Please use letters only (up to 30).';

  @override
  String get profileAddName => 'Add your name';

  @override
  String get planMapTitle => 'Your Live Well Map';

  @override
  String get planMapSubtitle => '8 Drivers for a Balanced Life';

  @override
  String get planMapCenter => 'Live Well';

  @override
  String get planMapEmpty => 'Take your 10-minute check to fill your map.';

  @override
  String planMapDriverLabel(String name, int percent) {
    return '$name: $percent% in the last 30 days. Opens details.';
  }

  @override
  String planMapDriverLabelEmpty(String name) {
    return '$name. Opens details.';
  }

  @override
  String planDriverBody(int percent) {
    return '$percent% of this driver’s steps done in the last 30 days.';
  }

  @override
  String get planDriverBodyEmpty =>
      'This part of your map fills in after your 10-minute check.';

  @override
  String get planGoalTitle => 'Your 30-Day Goal';

  @override
  String get planGoalEdit => 'Edit';

  @override
  String get planGoalEditLabel => 'Edit your 30-day goal';

  @override
  String planGoalDay(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String planGoalPercent(int percent) {
    return '$percent%';
  }

  @override
  String planGoalProgressLabel(int day, int total, int percent) {
    return 'Day $day of $total, $percent% done';
  }

  @override
  String get planGoalEmpty =>
      'Your 30-day goal is set after your 10-minute check.';

  @override
  String get planGoalEditSoonTitle => 'Changing your goal is coming soon';

  @override
  String get planGoalEditSoonBody =>
      'Soon you can change your 30-day goal here. Your coach will help you keep it small and doable.';

  @override
  String get planHabitsTitle => 'Daily Microhabits';

  @override
  String planHabitMenu(String title) {
    return 'More options for $title';
  }

  @override
  String get planHabitAbout => 'About this habit';

  @override
  String get planHabitSmaller => 'Make it smaller';

  @override
  String get planWeekTitle => 'Your week';

  @override
  String get planWeekOpen => 'Open your week';

  @override
  String get planWeekEmpty => 'Your plan’s days will show here.';

  @override
  String get planWeekToday => 'Today';

  @override
  String get planFrameworkRow => 'MY GOAL DO IT framework';

  @override
  String get planFrameworkRowBody =>
      'Your 10 building blocks, one letter at a time';

  @override
  String get trackPeriodWeek => 'This Week';

  @override
  String get trackPeriodMonth => 'This Month';

  @override
  String get trackPeriodQuarter => '90 days';

  @override
  String trackPeriodLabel(String period) {
    return 'Showing $period. Opens the choices.';
  }

  @override
  String get trackSteps => 'Steps';

  @override
  String trackStepsOf(String goal) {
    return 'of $goal';
  }

  @override
  String get trackConnectHealth => 'Connect Health';

  @override
  String get trackConnectHealthLabel =>
      'Steps: connect Apple Health or Health Connect. Opens details.';

  @override
  String get trackHealthSoonTitle => 'Connecting Health is coming soon';

  @override
  String get trackHealthSoonBody =>
      'Soon you can connect Apple Health or Health Connect. Your steps and sleep hours will show here, and only if you choose to share them.';

  @override
  String trackSleepHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get trackFromCheckIns => 'From your check-ins';

  @override
  String trackOutOf5(String value) {
    return '$value / 5';
  }

  @override
  String get trackNoCheckIns => 'No check-ins yet';

  @override
  String trackCardLabel(String name, String value, String detail) {
    return '$name: $value. $detail';
  }

  @override
  String get trackProgressTitle => 'Progress';

  @override
  String get trackThisWeekLabel => 'This week';

  @override
  String get trackChipHabits => 'Habits';

  @override
  String trackChartBarLabel(String day, String value) {
    return '$day: $value';
  }

  @override
  String trackChartBarEmpty(String day) {
    return '$day: nothing logged';
  }

  @override
  String trackChartSelected(String label) {
    return '$label. Selected.';
  }

  @override
  String get trackChartStepsEmpty => 'Connect Health to see your steps here.';

  @override
  String get trackChartHabitsEmpty =>
      'Your habits will show here once you start one.';

  @override
  String get trackChartEmpty => 'Check in to see your week here.';

  @override
  String trackHabitsKept(int count) {
    return '$count kept';
  }

  @override
  String get trackWeeklyTitle => 'Weekly Reflection';

  @override
  String get trackWeeklyQuestion => 'How was your week?';

  @override
  String get trackWeeklyBody =>
      'Celebrate your wins and set intentions for next week.';

  @override
  String get trackWeeklyLabel =>
      'How was your week? Opens your weekly reflection.';
}
