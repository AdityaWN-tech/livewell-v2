import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../avatar/presentation/coach_avatar.dart';
import '../../dev/application/preview_mode.dart';
import '../../home/application/home_data.dart';
import '../../moments/application/coach_state.dart';
import '../../moments/data/coach_faces.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show reminderTimesProvider;
import '../../starter_plan/domain/touchpoints.dart';
import '../../track/presentation/track_screen.dart'
    show streakProvider, todayReflectionProvider;
import '../data/widget_publisher.dart';
import '../domain/widget_builder.dart';
import '../domain/widget_snapshot.dart';

/// The faces the widget can show.
const widgetExpressions = [
  AvatarExpression.waving,
  AvatarExpression.happy,
  AvatarExpression.calm,
  AvatarExpression.listening,
  AvatarExpression.celebrating,
];

/// The coach's face files for the widget: the frame set's thumbnails on
/// the device, else the initial circle (the same files as the reminders).
final widgetFacesProvider = FutureProvider<Map<String, String>>((ref) async {
  await ref.watch(coachChoiceProvider.future);
  final name = ref.watch(coachNameProvider) ?? '';
  return ref
      .watch(coachFacesProvider)
      .byExpression(
        widgetExpressions,
        frames: await ref.watch(ownFrameSetProvider.future),
        initial: name.isEmpty ? '' : name.characters.first.toUpperCase(),
        background: ref.watch(coachBackgroundProvider),
      );
});

/// Today's state for the widget. Only whether the check-in happened and
/// whether it's a gentle day: never the answers (AGENTS.md).
final widgetInputsProvider = Provider<WidgetInputs>((ref) {
  final checkIn = ref.watch(todayCheckInProvider).value;
  final step = ref.watch(todayStepProvider);
  final progress = ref.watch(stepProgressProvider);
  return WidgetInputs(
    now: ref.watch(clockProvider)(),
    signedIn:
        ref.watch(signedInUidProvider) != null ||
        ref.watch(previewModeProvider),
    firstName: ref.watch(firstNameProvider),
    stepTitle: step?.title,
    smallerTitle: step?.smallerTitle,
    checkedIn: checkIn != null,
    gentleDay: checkIn?.gentleDay ?? false,
    safetyHold: ref.watch(safetyHoldTodayProvider),
    stepDone: progress.done,
    smaller: progress.smaller,
    reflected: ref.watch(todayReflectionProvider).value != null,
    times: ref.watch(reminderTimesProvider).value ?? const TouchpointTimes(),
    streakDays: ref.watch(streakProvider)?.length,
    avatarThumbs: ref.watch(widgetFacesProvider).value ?? const {},
    // TODO(T-AVT-08g-e): the "Hide details on lock screen" setting.
  );
});

/// The widget's words (the app is English only for now, spec Q7).
WidgetTexts widgetTexts(AppLocalizations l) => WidgetTexts(
  goodMorning: l.homeGreetingMorning,
  goodMorningNamed: l.homeGreetingMorningNamed,
  checkInSub: l.widgetCheckInSub,
  shorterOption: l.widgetShorter,
  timeFor: l.widgetTimeFor,
  dayN: l.widgetDayN,
  doneHeadline: l.widgetDoneHeadline,
  doneSub: l.widgetDoneSub,
  evening: l.widgetEvening,
  gentleSub: l.widgetGentleSub,
  noPlan: l.widgetNoPlan,
  signedOut: l.widgetSignedOut,
  lockNext: l.widgetLockNext,
  lockReady: l.widgetLockReady,
  lockDone: l.widgetLockDone,
  checkIn: l.momentActionCheckIn,
  start: l.widgetStart,
  makeSmaller: l.momentActionMakeSmaller,
  done: l.momentActionDone,
  reflect: l.widgetReflect,
  open: l.widgetOpen,
);

final widgetSnapshotProvider = Provider<WidgetSnapshot>(
  (ref) => WidgetSnapshotBuilder(
    widgetTexts(lookupAppLocalizations(const Locale('en'))),
  ).build(ref.watch(widgetInputsProvider)),
);

/// Keeps the widget up to date (FR-TCH-04): publishes whenever the plan,
/// check-in, step, reflection, coach, name or sign-in changes (a short
/// pause groups changes), on [refresh] (app resume) and at midnight. The
/// timeline in the snapshot covers the touchpoint times in between.
class WidgetSync {
  WidgetSync(this._ref) {
    // Back in the app: the time and the day may have moved on.
    _lifecycle = AppLifecycleListener(onResume: refresh);
    _ref.listen<WidgetSnapshot>(
      widgetSnapshotProvider,
      (_, _) => _soon(),
      fireImmediately: true,
    );
    _ref.onDispose(() {
      _lifecycle.dispose();
      _debounce?.cancel();
      _midnight?.cancel();
    });
  }

  final Ref _ref;
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;
  Timer? _midnight;

  static const pause = Duration(milliseconds: 300);

  /// The last snapshot handed to the widget (for tests and the Developer
  /// screen).
  WidgetSnapshot? last;

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(pause, publish);
  }

  /// Rebuilds from the current time and publishes now.
  Future<void> refresh() async {
    _ref.invalidate(widgetInputsProvider);
    await publish();
  }

  Future<void> publish() async {
    _debounce?.cancel();
    final snapshot = _ref.read(widgetSnapshotProvider);
    last = snapshot;
    await _ref.read(widgetPublisherProvider).publish(snapshot);
    _scheduleMidnight(snapshot.updatedAt);
  }

  void _scheduleMidnight(DateTime now) {
    _midnight?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), refresh);
  }
}

final widgetSyncProvider = Provider<WidgetSync>(WidgetSync.new);
