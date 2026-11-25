import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/auth/data/firebase_auth_service.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/application/coach_job_watcher.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/notifications/application/push_registrar.dart';
import 'package:livewell/features/notifications/data/device_registry.dart';
import 'package:livewell/features/notifications/data/push_messaging.dart';
import 'package:livewell/features/notifications/domain/push.dart';
import 'package:livewell/features/starter_plan/data/reminders.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import '../support/fakes.dart';

const texts = PushTexts(
  reminders: ReminderTexts(
    greetingTitle: 'Good morning',
    greetingBody: 'Your coach has a message for you.',
    nudgeTitle: 'Time for your small step',
    nudgeBody: 'Your coach has a message for you.',
    reflectionTitle: 'Good evening',
    reflectionBody: 'Your coach has a message for you.',
    weeklyTitle: 'Your week',
    weeklyBody: 'Your coach has a look back at your week for you.',
    channelName: 'Daily plan',
    routineTitle: 'Your routine',
    routineBody: 'Time for your next step.',
    routineBundleBody: 'A few things from your routine now.',
    routineChannelName: 'My Daily Routine',
  ),
  coach: CoachNoticeTexts(
    readyTitle: 'Your coach is ready',
    readyBody: 'Open Live Well to meet your new coach.',
    notMadeTitle: "We couldn't make your coach",
    notMadeBody: 'Open Live Well to try again.',
    channelName: 'Your coach',
  ),
);

void main() {
  late FakeAuthService auth;
  late FakeConsentRepository consents;
  late FakePushMessaging push;
  late FakeDeviceRegistry devices;
  late FakeReminders reminders;
  late ProviderContainer c;
  const path = 'users/u1/devices/install1';

  setUp(() {
    auth = FakeAuthService(signedIn: const AuthUser(uid: 'u1'));
    consents = FakeConsentRepository();
    push = FakePushMessaging();
    devices = FakeDeviceRegistry();
    reminders = FakeReminders()..zone = 'America/New_York';
    c = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        consentRepositoryProvider.overrideWithValue(consents),
        pushMessagingProvider.overrideWithValue(push),
        deviceRegistryProvider.overrideWithValue(devices),
        pushInstallIdStoreProvider.overrideWithValue(FakePushInstallIdStore()),
        remindersProvider.overrideWithValue(reminders),
      ],
    );
  });
  tearDown(() => c.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await c.read(pushRegistrarProvider).sync();
  }

  group('PushRegistrar (T-TCH-01)', () {
    test('without the notifications consent nothing is registered', () async {
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      expect(devices.docs, isEmpty);
    });

    test('without the OS permission nothing is registered, and it never '
        'asks for it', () async {
      push.allowed = false;
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      expect(devices.docs, isEmpty);
      expect(reminders.permissionAsks, 0);
    });

    test(
      'with consent and permission: token, platform and time zone only',
      () async {
        await consents.record(ConsentType.notifications, granted: true);
        await c.read(pushRegistrarProvider).start(texts);
        await settle();
        final d = devices.docs[path]!;
        expect(d.token, 'token-1');
        expect(d.platform, 'android');
        expect(d.timeZone, 'America/New_York');
      },
    );

    test('a new token replaces the old one', () async {
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      push.rotate('token-2');
      await settle();
      expect(devices.docs[path]!.token, 'token-2');
    });

    test(
      'turning the consent off removes the device and drops the token',
      () async {
        await consents.record(ConsentType.notifications, granted: true);
        await c.read(pushRegistrarProvider).start(texts);
        await settle();
        expect(devices.docs, contains(path));
        await consents.record(ConsentType.notifications, granted: false);
        await settle();
        expect(devices.docs, isEmpty);
        expect(push.deletes, greaterThan(0));
      },
    );

    test('log out removes the device and drops the token', () async {
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      await c.read(pushRegistrarProvider).unregister();
      expect(devices.docs, isEmpty);
      expect(push.deletes, 1);
    });

    test('signed out: nothing happens', () async {
      auth.signedIn = null;
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(pushRegistrarProvider).sync();
      expect(devices.docs, isEmpty);
    });

    test('a push while open shows the app\'s own generic words, never the '
        "push's, and opens like a reminder", () async {
      await consents.record(ConsentType.notifications, granted: true);
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      push.receive(const PushMessage(PushCategory.nudge, refId: 'x1'));
      await settle();
      expect(reminders.shown.single.$2, 'Time for your small step');
      expect(reminders.shownPayloads.single, 'nudge');
      push.receive(const PushMessage(PushCategory.coachReady, refId: 'job1'));
      await settle();
      expect(reminders.shown.last.$2, 'Your coach is ready');
    });

    test('a push while open shows nothing without the consent', () async {
      await c.read(pushRegistrarProvider).start(texts);
      await settle();
      push.receive(const PushMessage(PushCategory.greeting));
      await settle();
      expect(reminders.shown, isEmpty);
    });

    test('a tapped push hands its payload to Home', () async {
      final r = c.read(pushRegistrarProvider);
      final taps = <String>[];
      r.taps.listen(taps.add);
      await r.start(texts);
      push.tap(const PushMessage(PushCategory.reflection));
      await settle();
      expect(taps, ['reflection']);
      push.launch = const PushMessage(PushCategory.weekly);
      expect(await r.launchPayload(), 'weekly');
      expect(await r.launchPayload(), isNull);
    });
  });

  group('PushMessage.fromData', () {
    test('keeps only a known category and a plain ID', () {
      final m = PushMessage.fromData({
        'category': 'greeting',
        'ref_id': '2026-11-16',
        'title': 'anything',
      })!;
      expect(m.category, PushCategory.greeting);
      expect(m.refId, '2026-11-16');
      expect(PushMessage.fromData({'category': 'glucose'}), isNull);
      expect(
        PushMessage.fromData({'category': 'nudge', 'ref_id': 'a b/c'})!.refId,
        isNull,
      );
    });

    test('touchpoints open their moment; coach notices open the app', () {
      expect(const PushMessage(PushCategory.greeting).tapPayload, 'greeting');
      expect(
        const PushMessage(PushCategory.coachReady).tapPayload,
        'coach_ready',
      );
    });

    test('category keys match the server (src/push/copy.ts)', () {
      expect(PushCategory.values.map((c) => c.key), [
        'greeting',
        'nudge',
        'reflection',
        'weekly',
        'coach_ready',
        'coach_not_made',
      ]);
    });
  });
}
