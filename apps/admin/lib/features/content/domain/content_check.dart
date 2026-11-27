/// The check before anything goes for review (D-114, AGENTS.md safety
/// rules): no medication or dose advice, no cure or reversal promises,
/// no fear-based words. It flags; a person decides. Approval still needs
/// a second admin.
library;

class ContentIssue {
  const ContentIssue(this.phrase, this.why);
  final String phrase;
  final String why;
}

final _rules = <(String, String)>[
  (
    r'\b(stop|start|change|skip|reduce|increase|double)\b[^.\n]{0,30}\b(medicine|medication|meds|tablets?|pills?|insulin|dose|dosage)\b',
    'Medication or dose advice is not allowed. Say "talk to your doctor".',
  ),
  (r'\b\d+\s?(mg|mcg|units?)\b', 'Doses are not allowed in lessons.'),
  (
    r'\b(cures?|cured|reverse[sd]?|reversal|heals? (your )?(diabetes|cancer|disease))\b',
    'No cure or reversal promises.',
  ),
  (r'\bguarantee[sd]?\b', 'No guarantees about health results.'),
  (
    r'\b(you will die|deadly|fatal|before it.s too late|or else)\b',
    'Fear-based words go against the Live Well tone.',
  ),
].map((r) => (RegExp(r.$1, caseSensitive: false), r.$2)).toList();

/// Problems found in [text]; empty when it can go for review.
List<ContentIssue> checkContent(String text) => [
  for (final (re, why) in _rules)
    for (final m in re.allMatches(text)) ContentIssue(m.group(0)!, why),
];
