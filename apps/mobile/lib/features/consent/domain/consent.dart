/// Consent types (spec FR-ONB-02 legal documents and FR-ONB-03 granular,
/// revocable consents). The [key] is what is stored in Firestore; never rename it.
enum ConsentType {
  // Legal documents accepted during onboarding (FR-ONB-02). Required to use
  // the app; withdrawing them means closing the account (FR-SET-02).
  terms('terms', required: true),
  privacy('privacy', required: true),
  medicalDisclaimer('medical_disclaimer', required: true),
  aiDisclosure('ai_disclosure', required: true),

  // Granular consents, each granted or revoked on its own (FR-ONB-03).
  notifications('notifications'),
  healthData('health_data'),
  camera('camera'),
  microphone('microphone'),
  biometric('biometric'),
  portalLinking('portal_linking'),
  marketing('marketing'),
  analytics('analytics');

  const ConsentType(this.key, {this.required = false});

  final String key;

  /// Legal acceptance rather than an optional permission.
  final bool required;

  static List<ConsentType> get granular =>
      values.where((t) => !t.required).toList();

  static ConsentType? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// Version of the text the user saw when deciding. Every record stores it
/// (FR-ONB-02). All texts are drafts until counsel signs them off (T-CMP-01);
/// bump the version whenever the wording changes.
abstract final class ConsentTexts {
  static const draftVersion = '0.1-draft';

  static String versionOf(ConsentType type) => '${type.key}-$draftVersion';
}

/// One append-only consent record (users/{uid}/consents/{id}, spec 11).
class ConsentRecord {
  const ConsentRecord({
    required this.type,
    required this.docVersion,
    required this.granted,
    required this.appVersion,
    this.createdAt,
  });

  final ConsentType type;
  final String docVersion;
  final bool granted;
  final String appVersion;

  /// Server time; null while a new record is still pending offline.
  final DateTime? createdAt;
}

/// The current decision per type is the latest record for that type.
/// Records are never edited: a revocation is a newer record with
/// granted = false. Pending (offline) records count as newest.
Map<ConsentType, ConsentRecord> currentConsents(
  Iterable<ConsentRecord> records,
) {
  final sorted = records.toList()
    ..sort((a, b) {
      final ta = a.createdAt, tb = b.createdAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
  return {for (final r in sorted) r.type: r};
}

/// Granted unless the latest record says otherwise. No record = not granted.
bool isGranted(Map<ConsentType, ConsentRecord> current, ConsentType type) =>
    current[type]?.granted ?? false;
