import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/time/clock.dart';
import 'package:livewell/features/home/application/home_data.dart';
import 'package:livewell/features/home/presentation/home_screen.dart';
import 'package:livewell/features/starter_plan/domain/touchpoints.dart';
import 'package:livewell/features/widget/application/widget_settings.dart';
import 'package:livewell/features/widget/application/widget_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../profile/profile_test.dart' show openProfile, tapKey;

/// T-AVT-08g-e (T-TCH-02 PR TCH-e): the widget's privacy setting, sign-out
/// and the step reminder after Done.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> waitSync(WidgetTester tester) async {
    await tester.pump(WidgetSync.pause);
    await tester.pump();
  }

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.byKey(const Key('profile-widget-hide-details')),
      )
      .value;

  group('"Hide details on lock screen"', () {
    testWidgets('on by default: the widget is told to hide details', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await waitSync(tester);
      expect(h.widget.last!.hideDetails, isTrue);
      expect(h.widget.last!.toJson()['hide_details'], isTrue);
      await openProfile(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-widget-hide-details')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(switchValue(tester), isTrue);
    });

    testWidgets('turned off in Profile > Daily plan: saved on this phone and '
        'sent to the widget; turned back on, hidden again', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-widget-hide-details');
      expect(switchValue(tester), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(WidgetHideDetailsSetting.key), isFalse);
      await waitSync(tester);
      expect(h.widget.last!.hideDetails, isFalse);

      await tapKey(tester, 'profile-widget-hide-details');
      await waitSync(tester);
      expect(prefs.getBool(WidgetHideDetailsSetting.key), isTrue);
      expect(h.widget.last!.hideDetails, isTrue);
    });

    testWidgets('a saved "off" is kept after a restart', (tester) async {
      SharedPreferences.setMockInitialValues({
        WidgetHideDetailsSetting.key: false,
      });
      final h = signedIn();
      await h.boot(tester);
      await waitSync(tester);
      expect(h.widget.last!.hideDetails, isFalse);
    });
  });

  testWidgets("Done (in the app or from the widget) takes today's step "
      'reminder off', (tester) async {
    final h = signedIn();
    await h.boot(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    c.read(stepProgressActionsProvider).markDone();
    await tester.pump();
    expect(
      h.reminders.dismissed,
      contains(
        TouchpointScheduler.idFor(
          c.read(clockProvider)(),
          TouchpointKind.nudge,
        ),
      ),
    );
  });
}
