import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/account/application/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen_test.dart' show signedIn;
import '../profile/profile_test.dart' show openProfile, tapKey;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('optional fingerprint / face unlock (FR-ONB-01, D-62)', () {
    testWidgets('off by default: no lock, no prompt', (tester) async {
      final h = signedIn();
      await h.boot(tester);
      expect(find.byKey(const Key('app-lock')), findsNothing);
      expect(h.unlock.prompts, 0);
    });

    testWidgets('turning it on needs one unlock; then it is saved', (
      tester,
    ) async {
      final h = signedIn();
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-app-lock');
      expect(h.unlock.prompts, 1);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('profile-app-lock')))
            .value,
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppLockSetting.key), isTrue);
    });

    testWidgets('a phone without a screen lock: it stays off and says why', (
      tester,
    ) async {
      final h = signedIn();
      h.unlock.supported = false;
      await h.boot(tester);
      await openProfile(tester);
      await tapKey(tester, 'profile-app-lock');
      expect(find.textContaining('Set up a screen lock'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppLockSetting.key), isNot(true));
    });

    testWidgets('when on, the app opens locked and asks by itself; a failed '
        'unlock keeps it locked, Unlock tries again', (tester) async {
      SharedPreferences.setMockInitialValues({AppLockSetting.key: true});
      final h = signedIn();
      h.unlock.succeeds = false;
      await h.boot(tester);
      expect(find.byKey(const Key('app-lock')), findsOneWidget);
      expect(h.unlock.prompts, 1, reason: 'asked by itself once');
      h.unlock.succeeds = true;
      await tester.tap(find.byKey(const Key('app-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-lock')), findsNothing);
      expect(find.text('Live Well is locked'), findsNothing);
    });
  });
}
