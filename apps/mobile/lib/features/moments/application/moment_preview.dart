import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../home/application/home_data.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show reminderTimesProvider;
import '../../starter_plan/domain/touchpoints.dart';
import '../data/moment_templates_provider.dart';
import '../domain/coach_message.dart';
import '../domain/moment_builder.dart';
import 'coach_state.dart';

/// Why there is no preview to play.
enum PreviewBlock {
  /// A red flag today: the coach stays quiet, previews too (FR-VOC-07).
  safetyHold,

  /// No approved morning script (prod before clinical review).
  none,
}

/// Profile > Daily plan "Preview" (T-DLY-03e): tomorrow's morning moment,
/// from the same builder and approved scripts as the real one. Generic: only
/// the first name, the coach's name and the time of day go in; never the
/// Why, the step, the streak or anything from a check-in.
///
/// Returns the message, or why there is none.
final morningPreviewProvider =
    FutureProvider.autoDispose<(CoachMessage?, PreviewBlock?)>((ref) async {
      // A safety event today: no Avatar Moment of any kind. Safety events
      // are only kept for today so far (TODO(D-22): the 72-hour window).
      if (ref.watch(safetyHoldTodayProvider)) {
        return (null, PreviewBlock.safetyHold);
      }
      final now = ref.watch(clockProvider)();
      final times =
          ref.watch(reminderTimesProvider).value ?? const TouchpointTimes();
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day + 1,
        times.morning.hour,
        times.morning.minute,
      );
      final builder = await ref.watch(momentBuilderProvider.future);
      final m = builder.build(
        Moment.morning,
        MomentContext(
          now: tomorrow,
          firstName: ref.watch(firstNameProvider),
          coachName: ref.watch(coachNameProvider),
        ),
      );
      return (m, m == null ? PreviewBlock.none : null);
    });
