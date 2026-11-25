import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/monitoring/crash_reporting.dart';
import 'package:livewell/features/consent/domain/consent.dart';

/// T-FND-10 / D-80: crash reports carry no PHI or free text (NFR-10) and
/// nothing is collected without the analytics consent.

class RecordingSink implements CrashSink {
  final enabled = <bool>[];
  int deletes = 0;

  /// Everything that would leave the phone, as text.
  final sent = <String>[];
  final errors = <ScrubbedError>[];

  @override
  Future<void> setCollectionEnabled(bool on) async => enabled.add(on);

  @override
  Future<void> deleteUnsentReports() async => deletes++;

  @override
  Future<void> recordError(
    ScrubbedError error,
    StackTrace? stack, {
    required CrashReason reason,
    required bool fatal,
  }) async {
    errors.add(error);
    sent.add('$error | ${reason.name} | $fatal | $stack');
  }

  @override
  Future<void> log(CrashBreadcrumb b) async => sent.add('log ${b.name}');

  @override
  Future<void> setKey(CrashKey key, String value) async =>
      sent.add('key ${key.name}=$value');
}

ConsentRecord analytics(bool granted, int minute) => ConsentRecord(
  type: ConsentType.analytics,
  docVersion: 'analytics-0.1-draft',
  granted: granted,
  appVersion: '1.0.0',
  createdAt: DateTime.utc(2026, 11, 1, 9, minute),
);

/// Looks like what a user might type or what a health screen holds.
const phi = [
  'I feel awful today and skipped my pills',
  'mood=2',
  'sleep 4h',
  'stress 5/5',
  'glucose 182 mg/dL',
  'BP 150/95',
  'jane@example.com',
];

void main() {
  group('scrubbing', () {
    late RecordingSink sink;
    late CrashReporter crash;

    setUp(() async {
      sink = RecordingSink();
      crash = CrashReporter(sink);
      await crash.setEnabled(true);
    });

    test('an error keeps only its type name, never its message', () async {
      for (final text in phi) {
        await crash.recordError(
          StateError(text),
          StackTrace.current,
          reason: CrashReason.uncaughtAsync,
        );
        await crash.recordError(
          FormatException(text, text),
          null,
          reason: CrashReason.uncaughtAsync,
        );
        await crash.recordError(text, null, reason: CrashReason.uncaughtAsync);
        await crash.recordError(
          {'note': text},
          null,
          reason: CrashReason.uncaughtAsync,
        );
      }
      expect(sink.errors, hasLength(phi.length * 4));
      final everything = sink.sent.join('\n');
      for (final text in phi) {
        expect(everything, isNot(contains(text)));
      }
      expect(sink.errors.first, const ScrubbedError('StateError'));
      expect(sink.errors[1].type, 'FormatException');
      expect(sink.errors[2].type, 'String');
    });

    test('Flutter errors and uncaught async errors are scrubbed too', () async {
      final oldFlutter = FlutterError.onError;
      final oldPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = oldFlutter;
        PlatformDispatcher.instance.onError = oldPlatform;
      });
      // Don't print in the test output.
      FlutterError.onError = (_) {};
      crash.install();

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: Exception(phi.first),
          stack: StackTrace.current,
          informationCollector: () => [DiagnosticsNode.message(phi[1])],
        ),
      );
      final handled = PlatformDispatcher.instance.onError!(
        ArgumentError(phi[2]),
        StackTrace.current,
      );
      await pumpEventQueue();

      expect(handled, isTrue);
      expect(sink.errors.map((e) => e.type), ['_Exception', 'ArgumentError']);
      final everything = sink.sent.join('\n');
      for (final text in phi) {
        expect(everything, isNot(contains(text)));
      }
      expect(everything, contains('flutterError'));
      expect(everything, contains('uncaughtAsync'));
    });

    test('breadcrumbs and keys are fixed names', () async {
      await crash.breadcrumb(CrashBreadcrumb.appStarted);
      await crash.setKey(CrashKey.flavor, Flavor.prod);
      expect(sink.sent, ['log appStarted', 'key flavor=prod']);
    });
  });

  group('consent gating', () {
    test('nothing is sent while collection is off (the default)', () async {
      final sink = RecordingSink();
      final crash = CrashReporter(sink);
      expect(crash.enabled, isFalse);
      await crash.recordError(
        StateError('x'),
        null,
        reason: CrashReason.uncaughtAsync,
      );
      await crash.breadcrumb(CrashBreadcrumb.appStarted);
      await crash.setKey(CrashKey.flavor, Flavor.staging);
      expect(sink.sent, isEmpty);

      // The key waits for consent, then goes.
      await crash.setEnabled(true);
      expect(sink.sent, ['key flavor=staging']);
    });

    test('turning off also drops cached reports', () async {
      final sink = RecordingSink();
      final crash = CrashReporter(sink);
      await crash.setEnabled(true);
      await crash.setEnabled(false);
      expect(sink.enabled, [true, false]);
      expect(sink.deletes, 1);
    });

    Future<List<bool>> allowed(
      Flavor flavor, {
      bool devOptIn = false,
      required List<bool> signedIn,
      List<ConsentRecord> records = const [],
    }) => crashCollectionAllowed(
      flavor: flavor,
      devOptIn: devOptIn,
      signedIn: Stream.fromIterable(signedIn),
      consents: () => Stream.value(records),
    ).toList();

    for (final flavor in [Flavor.staging, Flavor.prod]) {
      test('${flavor.name}: off without the analytics consent', () async {
        expect(await allowed(flavor, signedIn: [false]), [false]);
        expect(await allowed(flavor, signedIn: [true]), [false]);
        expect(
          await allowed(
            flavor,
            signedIn: [true],
            records: [analytics(true, 1), analytics(false, 2)],
          ),
          [false],
        );
      });

      test('${flavor.name}: sign-out turns it off even if the consent '
          'listener never ends (offline)', () async {
        final signedIn = StreamController<bool>();
        final open = StreamController<List<ConsentRecord>>(); // never closed
        final seen = <bool>[];
        final sub = crashCollectionAllowed(
          flavor: flavor,
          devOptIn: false,
          signedIn: signedIn.stream,
          consents: () => open.stream,
        ).listen(seen.add);
        signedIn.add(true);
        await pumpEventQueue();
        open.add([analytics(true, 1)]);
        await pumpEventQueue();
        signedIn.add(false);
        await pumpEventQueue();
        expect(seen, [true, false]);
        await sub.cancel();
        await signedIn.close();
        await open.close();
      });

      test('${flavor.name}: on with it, off again after sign-out', () async {
        expect(
          await allowed(
            flavor,
            signedIn: [true, false],
            records: [analytics(true, 1)],
          ),
          [true, false],
        );
      });

      test('${flavor.name}: other consents do not count', () async {
        final others = [
          for (final t in ConsentType.values)
            if (t != ConsentType.analytics)
              ConsentRecord(
                type: t,
                docVersion: 'v',
                granted: true,
                appVersion: '1',
              ),
        ];
        expect(await allowed(flavor, signedIn: [true], records: others), [
          false,
        ]);
      });
    }

    test('dev: off by default even with the consent', () async {
      expect(
        await allowed(
          Flavor.dev,
          signedIn: [true],
          records: [analytics(true, 1)],
        ),
        [false],
      );
      expect(devCrashReportsOptIn, isFalse);
    });

    test('dev with LW_CRASH_REPORTS: still needs the consent', () async {
      expect(await allowed(Flavor.dev, devOptIn: true, signedIn: [true]), [
        false,
      ]);
      expect(
        await allowed(
          Flavor.dev,
          devOptIn: true,
          signedIn: [true],
          records: [analytics(true, 1)],
        ),
        [true],
      );
    });

    test('a consent read error turns collection off', () async {
      final sink = RecordingSink();
      final crash = CrashReporter(sink);
      await crash.setEnabled(true);
      final c = StreamController<bool>();
      crash.follow(c.stream);
      c.addError(StateError('permission-denied'));
      await pumpEventQueue();
      expect(crash.enabled, isFalse);
      await c.close();
    });
  });
}
