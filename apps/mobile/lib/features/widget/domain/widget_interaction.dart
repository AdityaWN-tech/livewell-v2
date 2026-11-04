import 'widget_snapshot.dart';

/// One tap on the home-screen widget, for `widget_interaction {action,
/// size, slot}` (spec 12.2; T-TCH-02 TCH-e). Every field is a fixed name
/// from an allow-list, never text from the widget, so nothing personal can
/// reach analytics (AGENTS.md). Anything else becomes [unknown].
class WidgetInteraction {
  WidgetInteraction({required String action, String? size, String? slot})
    : action = actions.contains(action) ? action : unknown,
      size = sizes.contains(size) ? size! : unknown,
      slot = slots.contains(slot) ? slot! : unknown;

  /// Done tapped on the widget itself (iOS 17+, Android), applied by the app
  /// later; the native side keeps the size and slot it was tapped in.
  factory WidgetInteraction.doneOnWidget({String? size, String? slot}) =>
      WidgetInteraction(action: WidgetActionId.done.id, size: size, slot: slot);

  final String action;
  final String size;
  final String slot;

  static const unknown = 'unknown';

  static final actions = {for (final a in WidgetActionId.values) a.id};

  /// iOS: small, medium, large and the lock-screen rectangle; Android:
  /// small, and medium when wider than 250 dp.
  static const sizes = {'small', 'medium', 'large', 'lock_rectangular'};
  static final slots = {for (final s in WidgetSlot.values) s.id};

  @override
  bool operator ==(Object other) =>
      other is WidgetInteraction &&
      other.action == action &&
      other.size == size &&
      other.slot == slot;

  @override
  int get hashCode => Object.hash(action, size, slot);

  @override
  String toString() => 'WidgetInteraction($action, $size, $slot)';
}
