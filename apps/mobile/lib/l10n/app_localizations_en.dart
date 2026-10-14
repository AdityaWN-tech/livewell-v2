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
  String get checkinStress2 => 'A little';

  @override
  String get checkinStress3 => 'Some';

  @override
  String get checkinStress4 => 'A lot';

  @override
  String get checkinStress5 => 'Very';

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
}
