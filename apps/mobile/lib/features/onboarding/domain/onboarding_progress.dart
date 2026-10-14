import '../../consent/domain/consent.dart';

/// Onboarding steps before an account exists, in order (spec 5.2, D-19).
/// The 18+ check comes before sign-in so nothing is stored for under-18s
/// (FR-ONB-04).
enum OnboardingStep {
  welcome('/welcome'),
  about('/onboarding/about'),
  age('/onboarding/age'),
  legal('/onboarding/legal'),
  signIn('/sign-in');

  const OnboardingStep(this.path);

  /// Where to resume (FR-ONB-06).
  final String path;

  static OnboardingStep fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => welcome);
}

/// The legal documents accepted during onboarding (FR-ONB-02).
List<ConsentType> get legalDocuments =>
    ConsentType.values.where((t) => t.required).toList();

/// Progress kept on the device until the account is created, then turned
/// into the profile and consent records and cleared.
class OnboardingProgress {
  const OnboardingProgress({
    this.step = OnboardingStep.welcome,
    this.adultConfirmedAt,
    this.legalAcceptedAt = const {},
  });

  final OnboardingStep step;

  /// When the user confirmed they are 18 or older.
  final DateTime? adultConfirmedAt;

  /// When each legal document was accepted (stored as its granted_at).
  final Map<ConsentType, DateTime> legalAcceptedAt;

  bool get isAdult => adultConfirmedAt != null;

  bool get allLegalAccepted =>
      legalDocuments.every(legalAcceptedAt.containsKey);

  /// Ready to create the account's profile and consent records.
  bool get readyForAccount => isAdult && allLegalAccepted;

  OnboardingProgress copyWith({
    OnboardingStep? step,
    DateTime? adultConfirmedAt,
    Map<ConsentType, DateTime>? legalAcceptedAt,
  }) => OnboardingProgress(
    step: step ?? this.step,
    adultConfirmedAt: adultConfirmedAt ?? this.adultConfirmedAt,
    legalAcceptedAt: legalAcceptedAt ?? this.legalAcceptedAt,
  );

  Map<String, Object?> toJson() => {
    'step': step.name,
    'adult_confirmed_at': adultConfirmedAt?.toUtc().toIso8601String(),
    'legal_accepted_at': {
      for (final e in legalAcceptedAt.entries)
        e.key.key: e.value.toUtc().toIso8601String(),
    },
  };

  static OnboardingProgress fromJson(Map<String, Object?> json) {
    final legal = (json['legal_accepted_at'] as Map?) ?? const {};
    return OnboardingProgress(
      step: OnboardingStep.fromName(json['step'] as String?),
      adultConfirmedAt: DateTime.tryParse(
        json['adult_confirmed_at'] as String? ?? '',
      ),
      legalAcceptedAt: {
        for (final e in legal.entries)
          // Unknown types or unreadable times are skipped.
          ?ConsentType.fromKey(e.key as String): ?DateTime.tryParse(
            e.value as String? ?? '',
          ),
      },
    );
  }
}
