import '../../safety/domain/safety_rules.dart';

/// Checks for custom routine labels (T-GOL-03c). The shared red-flag rules
/// run first; then the short-label rules (packages/safety-rules/
/// label_rules.json), because labels are short commands ("Skip dinner")
/// that the sentence patterns don't catch. Nothing flagged is saved.

/// What a short-label rule found, in priority order.
enum LabelKind {
  /// Shows the disordered-eating card (FR-SAF-04).
  disorderedEating('disordered_eating'),

  /// Medicines and supplements aren't routine items in v2.
  medication('medication'),

  /// Weight, calories, fasting and diets (spec 4.1, 14.1).
  notAllowed('not_allowed'),

  /// Shaming words.
  unkind('unkind');

  const LabelKind(this.key);

  final String key;

  static LabelKind fromKey(String key) =>
      values.firstWhere((k) => k.key == key);
}

class LabelRule {
  LabelRule(this.id, this.kind, List<String> patterns)
    : _patterns = [for (final p in patterns) RegExp(p)];

  final String id;
  final LabelKind kind;
  final List<RegExp> _patterns;

  bool matches(String normalised) =>
      _patterns.any((p) => p.hasMatch(normalised));
}

class LabelRules {
  LabelRules({required this.version, required this.rules});

  factory LabelRules.fromJson(Map<String, dynamic> json) => LabelRules(
    version: json['version'] as String,
    rules: [
      for (final r in (json['rules'] as List).cast<Map<String, dynamic>>())
        LabelRule(
          r['id'] as String,
          LabelKind.fromKey(r['kind'] as String),
          (r['patterns'] as List).cast<String>(),
        ),
    ],
  );

  final String version;
  final List<LabelRule> rules;

  /// The highest-priority kind matched, or null. Same normalisation as the
  /// red-flag rules.
  LabelKind? check(String text) {
    final t = SafetyRules.normalise(text);
    if (t.isEmpty) return null;
    LabelKind? best;
    for (final r in rules) {
      if (r.matches(t) && (best == null || r.kind.index < best.index)) {
        best = r.kind;
      }
    }
    return best;
  }
}

/// The verdict on a custom label.
sealed class LabelVerdict {
  const LabelVerdict();
}

/// Fine to save.
class LabelOk extends LabelVerdict {
  const LabelOk();
}

/// A red flag: show the safety response for [result]; never saved. A
/// disordered-eating label from the short-label rules comes here too, so it
/// gets the same card.
class LabelRedFlag extends LabelVerdict {
  const LabelRedFlag(this.result);
  final SafetyResult result;
}

/// Not a red flag, but not a routine step: a kind message, and the person
/// can change the words.
class LabelBlocked extends LabelVerdict {
  const LabelBlocked(this.kind);
  final LabelKind kind;
}

LabelVerdict checkLabel(String label, SafetyRules shared, LabelRules labels) {
  final red = shared.check(label);
  if (!red.isClear) return LabelRedFlag(red);
  final kind = labels.check(label);
  return switch (kind) {
    null => const LabelOk(),
    LabelKind.disorderedEating => const LabelRedFlag(
      SafetyResult(SafetyCategory.disorderedEating, ['LBL-ED']),
    ),
    _ => LabelBlocked(kind),
  };
}
