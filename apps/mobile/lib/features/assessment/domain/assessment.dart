/// The 10-minute check (ASM-01, D-114): admin-written questions, answered
/// 1 (not at all) to 5 (completely); each counts towards one of the 8
/// drivers of the Live Well Map. Taps only, no free text, so nothing here
/// needs the red-flag text rules. PROVISIONAL scoring until clinical review.
library;

class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.driverId,
    required this.text,
    this.order = 0,
    this.version = 1,
  });

  final String id;

  /// driver_1 .. driver_8.
  final String driverId;
  final String text;
  final int order;
  final int version;
}

/// Questions in asking order: driver by driver, then by their order.
List<AssessmentQuestion> askingOrder(List<AssessmentQuestion> qs) =>
    [...qs]..sort((a, b) {
      final c = a.driverId.compareTo(b.driverId);
      return c != 0 ? c : a.order.compareTo(b.order);
    });

/// Each driver's share of its best answers, 0..1: the mean of (answer - 1)
/// / 4 over its questions. Drivers without questions are left out.
Map<String, double> driverScores(
  List<AssessmentQuestion> questions,
  Map<String, int> answers,
) {
  final sums = <String, (double, int)>{};
  for (final q in questions) {
    final a = answers[q.id];
    if (a == null || a < 1 || a > 5) continue;
    final (s, n) = sums[q.driverId] ?? (0.0, 0);
    sums[q.driverId] = (s + (a - 1) / 4, n + 1);
  }
  return {for (final e in sums.entries) e.key: e.value.$1 / e.value.$2};
}

/// Which questions (and versions) were asked, kept with the answers.
String bankVersion(List<AssessmentQuestion> qs) =>
    (askingOrder(qs).map((q) => '${q.id}@${q.version}').toList()).join(',');
