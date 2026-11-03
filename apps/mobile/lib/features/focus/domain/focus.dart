import 'dart:convert';

/// "What would you like to work on this week?" (T-ONB-03d). Ids are stored
/// in users/{uid}.focus_choices and checked by the Firestore rules.
enum FocusArea {
  moveMore('move_more'),
  sleepBetter('sleep_better'),
  eatBetter('eat_better'),
  lessStress('less_stress'),
  moreEnergy('more_energy'),
  healthyRoutine('healthy_routine');

  const FocusArea(this.id);

  final String id;

  static FocusArea? byId(String id) =>
      values.where((f) => f.id == id).firstOrNull;
}

/// Pick 1, optionally a 2nd. The first is the main focus.
abstract final class FocusRules {
  static const maxChoices = 2;
}

/// content/plan/focus_to_driver.json: each focus's driver and whether a
/// movement plan may follow (then the FR-GOL-03 activity check runs).
/// Pending clinical review; driver keys are provisional (needs-product).
class FocusMap {
  const FocusMap(this._entries);

  final Map<FocusArea, ({String driver, bool involvesMovement})> _entries;

  static FocusMap parse(String json) {
    final focus =
        (jsonDecode(json) as Map<String, dynamic>)['focus']
            as Map<String, dynamic>;
    return FocusMap({
      for (final f in FocusArea.values)
        f: (
          driver: (focus[f.id] as Map<String, dynamic>)['driver'] as String,
          involvesMovement:
              (focus[f.id] as Map<String, dynamic>)['involves_movement']
                  as bool,
        ),
    });
  }

  String driverOf(FocusArea f) => _entries[f]!.driver;

  bool involvesMovement(FocusArea f) => _entries[f]!.involvesMovement;

  /// The activity check runs before any plan that may include movement.
  bool needsActivityCheck(List<FocusArea> choices) =>
      choices.any(involvesMovement);
}
