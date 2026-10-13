/// Deterministic red-flag rules engine (T-ASM-02, FR-SAF-01..05).
///
/// Plain code, no AI: it cannot be talked out of a decision (spec 9.1). The
/// rules are data in packages/safety-rules/rules.json, shared with the agents
/// service, and both engines must pass packages/safety-rules/cases.json.
/// HUMAN REVIEW REQUIRED: the Clinical Content and Safety Committee reviews
/// the rules and the messages shown for them.
library;

/// Red-flag categories, highest priority first.
enum SafetyCategory {
  emergency('emergency'),
  crisis('crisis'),
  disorderedEating('disordered_eating'),
  medication('medication'),
  pregnancyComplex('pregnancy_complex');

  const SafetyCategory(this.key);

  final String key;

  /// Emergency and crisis stop whatever the user was doing (FR-SAF-01/02).
  bool get interrupts =>
      this == SafetyCategory.emergency || this == SafetyCategory.crisis;

  static SafetyCategory fromKey(String key) =>
      values.firstWhere((c) => c.key == key);
}

/// Phone numbers per region (D-03). Region unknown: both are shown.
class SafetyContacts {
  const SafetyContacts({
    required this.region,
    required this.emergency,
    required this.crisisCall,
    required this.crisisName,
    this.crisisText,
  });

  final String region;
  final String emergency;
  final String crisisCall;
  final String? crisisText;
  final String crisisName;
}

class SafetyRule {
  SafetyRule(this.id, this.category, List<String> patterns)
    : _patterns = [for (final p in patterns) RegExp(p)];

  final String id;
  final SafetyCategory category;
  final List<RegExp> _patterns;

  bool matches(String normalised) =>
      _patterns.any((p) => p.hasMatch(normalised));
}

/// What the engine found in a piece of text.
class SafetyResult {
  const SafetyResult(this.category, this.ruleIds);

  static const clear = SafetyResult(null, []);

  /// The highest-priority category matched, or null.
  final SafetyCategory? category;

  /// Every matching rule id (for the safety event log, FR-SAF-06).
  final List<String> ruleIds;

  bool get isClear => category == null;
  bool get interrupts => category?.interrupts ?? false;
}

class SafetyRules {
  SafetyRules({
    required this.version,
    required this.rules,
    required this.contacts,
  });

  factory SafetyRules.fromJson(Map<String, dynamic> json) => SafetyRules(
    version: json['version'] as String,
    rules: [
      for (final r in (json['rules'] as List).cast<Map<String, dynamic>>())
        SafetyRule(
          r['id'] as String,
          SafetyCategory.fromKey(r['category'] as String),
          (r['patterns'] as List).cast<String>(),
        ),
    ],
    contacts: {
      for (final e in (json['contacts'] as Map<String, dynamic>).entries)
        e.key: SafetyContacts(
          region: e.key,
          emergency: e.value['emergency'] as String,
          crisisCall: e.value['crisis_call'] as String,
          crisisText: e.value['crisis_text'] as String?,
          crisisName: e.value['crisis_name'] as String,
        ),
    },
  );

  final String version;
  final List<SafetyRule> rules;
  final Map<String, SafetyContacts> contacts;

  /// Same normalisation as the reference engine (check_cases.py).
  static String normalise(String text) => text
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  SafetyResult check(String text) {
    final t = normalise(text);
    if (t.isEmpty) return SafetyResult.clear;
    final matched = [
      for (final r in rules)
        if (r.matches(t)) r,
    ];
    if (matched.isEmpty) return SafetyResult.clear;
    final best = matched
        .map((r) => r.category)
        .reduce((a, b) => a.index <= b.index ? a : b);
    return SafetyResult(best, [for (final r in matched) r.id]);
  }

  /// Numbers for [region] ('US' / 'IN'), or every region when unknown (D-03).
  List<SafetyContacts> contactsFor(String? region) {
    final c = contacts[region];
    return c != null ? [c] : contacts.values.toList();
  }
}
