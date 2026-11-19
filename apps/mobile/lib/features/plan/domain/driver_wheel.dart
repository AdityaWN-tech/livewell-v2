import 'dart:convert';

import '../../focus/domain/focus.dart';
import '../../goals/domain/goal.dart' show dailyStepHabitId;
import '../../starter_plan/domain/starter_plan.dart';
import 'plan_models.dart';

/// content/plan/drivers.json: the one source of the 8 drivers for the Live
/// Well Map (FR-GAM-02, D-87). PROVISIONAL, pending clinical review: the
/// names come from the assessment content (T-ASM-01), which doesn't exist
/// yet, so the labels are numbers only.
class DriverCatalog {
  const DriverCatalog({
    required this.reviewStatus,
    required this.provisional,
    required this.drivers,
    required this.focusDrivers,
  });

  final String reviewStatus;

  /// True until the clinical team confirms the names, order and keys.
  final bool provisional;

  /// In wheel order.
  final List<Driver> drivers;

  /// For each driver (same order), the focus_to_driver.json keys that count
  /// towards it.
  final List<List<String>> focusDrivers;

  /// Before the file loads: numbered drivers, nothing mapped.
  static final fallback = DriverCatalog(
    reviewStatus: 'pending',
    provisional: true,
    drivers: [
      for (var i = 0; i < 8; i++) Driver(index: i, label: 'Driver ${i + 1}'),
    ],
    focusDrivers: List.filled(8, const []),
  );

  static DriverCatalog parse(String json) {
    final d = jsonDecode(json) as Map<String, dynamic>;
    final list = (d['drivers'] as List).cast<Map<String, dynamic>>();
    return DriverCatalog(
      reviewStatus: d['review_status'] as String,
      provisional: d['provisional'] as bool,
      drivers: [
        for (final (i, x) in list.indexed)
          Driver(index: i, label: x['label'] as String),
      ],
      focusDrivers: [
        for (final x in list) (x['focus_drivers'] as List).cast<String>(),
      ],
    );
  }

  /// The wheel segment a focus driver key counts towards, or null.
  int? indexOf(String focusDriver) {
    for (final (i, keys) in focusDrivers.indexed) {
      if (keys.contains(focusDriver)) return i;
    }
    return null;
  }
}

/// FR-GAM-02: each segment reflects habit completion in that driver over 30
/// days. Planned = the plan's daily step and supporting habits on each day
/// (the step's focus gives the driver); done = their habit_logs. The
/// person's own habits have no driver yet and don't count.
abstract final class DriverWheel {
  static const days = 30;

  /// 0..1 per driver, or null when no plan day falls in the window (the
  /// wheel then stays soft grey). Days after [today] don't count, and
  /// today's habits count only once done (the day isn't over).
  static List<double>? completion({
    required DriverCatalog catalog,
    required FocusMap focus,
    required Iterable<PlanDay> planDays,
    required Set<String> doneLogIds,
    required String today,
  }) {
    final n = catalog.drivers.length;
    final planned = List.filled(n, 0);
    final done = List.filled(n, 0);
    var any = false;
    for (final day in planDays) {
      if (day.date.compareTo(today) > 0) continue;
      final i = catalog.indexOf(focus.driverOf(day.focus));
      if (i == null) continue;
      any = true;
      final ids = [
        dailyStepHabitId,
        for (final s in day.supporting) 'support-${s.id}',
      ];
      for (final id in ids) {
        final isDone = doneLogIds.contains('${day.date}_$id');
        if (day.date == today && !isDone) continue;
        planned[i]++;
        if (isDone) done[i]++;
      }
    }
    if (!any) return null;
    return [
      for (var i = 0; i < n; i++) planned[i] == 0 ? 0.0 : done[i] / planned[i],
    ];
  }
}
