import 'dart:io';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/avatar/data/avatar_maker_api.dart';
import 'package:livewell/features/avatar/data/selfie_capture.dart';
import 'package:livewell/features/avatar/domain/coach_choice.dart';
import 'package:livewell/features/avatar/domain/liveness.dart';
import 'package:livewell/features/avatar/presentation/selfie_screen.dart';
import 'package:livewell/features/consent/domain/consent.dart';

import '../studio/studio_test.dart' show openStudio, tapKey;
import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-AVT-08e: "Make me from my photo": consents first, a live selfie with
/// liveness, sent once, never kept.

const uid = 'u1';

Harness photoOn({bool flag = true}) {
  final h = Harness(
    flags: FeatureFlags(avatarFromPhoto: flag),
    auth: FakeAuthService(signedIn: const AuthUser(uid: uid)),
  );
  h.profiles.existing[uid] = ProfileStep.assessment;
  return h;
}

FaceObservation face({
  double eyes = 0.9,
  double width = 0.5,
  double off = 0.02,
  double yaw = 0,
  int faces = 1,
}) => FaceObservation(
  faces: faces,
  leftEyeOpen: eyes,
  rightEyeOpen: eyes,
  yaw: yaw,
  widthShare: width,
  offCentre: off,
);

Set<ConsentType> granted(Harness h) => {
  for (final r in h.consents.records)
    if (r.granted) r.type,
};

/// Studio > From my photo > Take a live selfie (> Allow).
Future<void> start(WidgetTester tester, Harness h, {bool allow = true}) async {
  await h.boot(tester);
  await openStudio(tester);
  await tapKey(tester, 'studio-tab-photo');
  await tapKey(tester, 'photo-start');
  await tester.tap(
    find.byKey(Key(allow ? 'photo-consent-yes' : 'photo-consent-no')),
  );
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('liveness (on the phone)', () {
    test('a blink: open, closed, open again', () {
      final t = LivenessTracker();
      expect(t.see(face()), SelfieTip.blink);
      expect(t.see(face(eyes: 0.1)), SelfieTip.blink);
      expect(t.passed, isFalse);
      expect(t.see(face()), SelfieTip.ready);
      expect(t.passed, isTrue);
    });

    test('closed eyes first are not a blink', () {
      final t = LivenessTracker();
      t
        ..see(face(eyes: 0.1))
        ..see(face());
      expect(t.passed, isFalse);
    });

    test('a head turn and back', () {
      final t = LivenessTracker(LivenessMethod.turn);
      expect(t.see(face(yaw: 25)), SelfieTip.turn);
      expect(t.see(face()), SelfieTip.ready);
    });

    test('tips: no face, own face only, closer, back, centre', () {
      final t = LivenessTracker();
      expect(t.see(FaceObservation.none), SelfieTip.noFace);
      expect(t.see(face(faces: 2)), SelfieTip.oneFaceOnly);
      expect(t.see(face(width: 0.1)), SelfieTip.moveCloser);
      expect(t.see(face(width: 0.9)), SelfieTip.moveBack);
      expect(t.see(face(off: 0.4)), SelfieTip.centre);
    });

    test('someone else in the picture starts it over', () {
      final t = LivenessTracker()
        ..see(face())
        ..see(face(eyes: 0.1))
        ..see(face());
      expect(t.passed, isTrue);
      t.see(face(faces: 2));
      expect(t.passed, isFalse);
    });

    test('the photo is taken looking at the camera, eyes open', () {
      final t = LivenessTracker()
        ..see(face())
        ..see(face(eyes: 0.1))
        ..see(face());
      expect(t.see(face(yaw: 20)), SelfieTip.centre);
      expect(t.see(face(eyes: 0.1)), SelfieTip.centre);
      expect(t.see(face()), SelfieTip.ready);
    });
  });

  test(
    "the camera's photo file is deleted once read, even if reading fails",
    () async {
      final dir = Directory.systemTemp.createTempSync('photo');
      final file = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      expect(await readAndDelete(XFile(file.path)), [1, 2, 3]);
      expect(file.existsSync(), isFalse);
      await expectLater(
        readAndDelete(XFile('${dir.path}/missing.jpg')),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('never the gallery: the avatar feature has no image picker', () {
    for (final f in Directory(
      'lib/features/avatar',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      expect(
        f.readAsStringSync(),
        isNot(contains('image_picker')),
        reason: f.path,
      );
    }
  });

  testWidgets('flag off (prod until counsel review): "Coming soon" only', (
    tester,
  ) async {
    final h = photoOn(flag: false);
    await h.boot(tester);
    await openStudio(tester);
    await tapKey(tester, 'studio-tab-photo');
    expect(find.byKey(const Key('studio-photo-soon')), findsOneWidget);
    expect(find.byKey(const Key('photo-start')), findsNothing);
  });

  testWidgets('consents are asked before the camera opens; "Not now" opens '
      'nothing and offers the other ways', (tester) async {
    final h = photoOn();
    await start(tester, h, allow: false);
    expect(h.selfieCapture.starts, 0);
    expect(granted(h), isEmpty);
    expect(find.byType(SelfieScreen), findsNothing);
    expect(find.byKey(const Key('photo-declined')), findsOneWidget);
    await tapKey(tester, 'photo-declined-coaches');
    expect(find.byKey(const Key('coach-brown_hair')), findsOneWidget);
  });

  testWidgets('the consent says what happens, the 7 days, and how to delete', (
    tester,
  ) async {
    final h = photoOn();
    await h.boot(tester);
    await openStudio(tester);
    await tapKey(tester, 'studio-tab-photo');
    await tapKey(tester, 'photo-start');
    final text = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('photo-consent')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join(' ');
    for (final words in [
      'Camera',
      'Face processing',
      'not from your gallery',
      'deleted right after',
      'at most 7 days',
      'never used to train AI',
      'delete your coach',
    ]) {
      expect(text, contains(words));
    }
  });

  testWidgets('allow: both consents recorded; a live blink; the photo is sent '
      'once and its file deleted; the coach comes back made', (tester) async {
    final h = photoOn();
    h.avatarMaker.onMade = () => h.avatars.saved = const CoachChoice(
      source: CoachSource.selfie,
      framesVersion: 1,
    );
    await start(tester, h);
    expect(granted(h), {ConsentType.camera, ConsentType.biometric});
    expect(find.byType(SelfieScreen), findsOneWidget);
    expect(h.selfieCapture.starts, 1);
    expect(find.text('Put your face in the circle'), findsOneWidget);

    Future<void> take() async {
      final button = find.byKey(const Key('selfie-take'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }

    // Not ready before a blink: the button waits.
    h.selfieCapture.see(face());
    await settle(tester);
    expect(find.text('Now blink slowly'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('selfie-take')))
          .onPressed,
      isNull,
    );
    h.selfieCapture.blink();
    await settle(tester);
    expect(find.text('Great! Take your photo'), findsOneWidget);
    await take();
    await settle(tester);
    expect(find.byKey(const Key('selfie-making')), findsOneWidget);
    // Sent once, with how liveness was shown; the camera file is gone.
    expect(h.avatarMaker.sent, hasLength(1));
    expect(h.avatarMaker.sent.single.$2, LivenessMethod.blink);
    expect(h.avatarMaker.sent.single.$1.take(3), [0xFF, 0xD8, 0xFF]);
    expect(File(h.selfieCapture.lastPhotoPath!).existsSync(), isFalse);

    // The job runs; then the Studio has the new coach.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.pumpAndSettle();
    expect(find.byType(SelfieScreen), findsNothing);
    expect(find.text('Your coach is ready.'), findsOneWidget);
    expect(h.selfieCapture.closed, isTrue);
  });

  testWidgets("can't blink: turn the head instead", (tester) async {
    final h = photoOn();
    await start(tester, h);
    await tapKey(tester, 'selfie-switch');
    h.selfieCapture
      ..see(face(yaw: 25))
      ..see(face());
    await settle(tester);
    expect(find.text('Great! Take your photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('selfie-take')));
    await settle(tester);
    expect(h.avatarMaker.sent.single.$2, LivenessMethod.turn);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  for (final (refusal, message, retry) in [
    ('avatar_daily_limit', "You've made 3 coaches today.", false),
    ('not_configured', "isn't available yet", false),
    ('network', "We couldn't reach our service", true),
  ]) {
    testWidgets('$refusal: a kind message', (tester) async {
      final h = photoOn();
      h.avatarMaker.refuse = AvatarMakerError(refusal);
      await start(tester, h);
      h.selfieCapture.blink();
      await settle(tester);
      await tester.tap(find.byKey(const Key('selfie-take')));
      await settle(tester);
      expect(find.textContaining(message), findsOneWidget);
      expect(
        find.byKey(const Key('selfie-retry')),
        retry ? findsOneWidget : findsNothing,
      );
      // The photo file is gone even though it wasn't sent.
      expect(File(h.selfieCapture.lastPhotoPath!).existsSync(), isFalse);
      await tapKey(tester, 'selfie-pick-ready');
      expect(find.byType(SelfieScreen), findsNothing);
    });
  }

  testWidgets('a coach that could not be made: try again opens the camera', (
    tester,
  ) async {
    final h = photoOn();
    h.avatarMaker.statuses = [
      const AvatarJobStatus(status: 'rejected', messageId: 'avatar_not_made'),
    ];
    await start(tester, h);
    h.selfieCapture.blink();
    await settle(tester);
    await tester.tap(find.byKey(const Key('selfie-take')));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.textContaining('try a different photo'), findsOneWidget);
    await tapKey(tester, 'selfie-retry');
    expect(h.selfieCapture.starts, 2);
    expect(find.text('Put your face in the circle'), findsOneWidget);
  });

  testWidgets('no camera: says so', (tester) async {
    final h = photoOn();
    h.selfieCapture.works = false;
    await start(tester, h);
    expect(find.text("We couldn't open the camera."), findsOneWidget);
  });
}
