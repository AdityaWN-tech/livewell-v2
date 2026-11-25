import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consent/domain/consent.dart';
import '../config/flavor.dart';

/// Crash reporting (T-FND-10, D-80; spec 10.2 "Crashlytics (PHI scrubbed)",
/// NFR-10 "No PHI or free text in crash logs").
///
/// Everything sent goes through [CrashReporter], which can only send:
/// - the error's **type name** and stack trace, never its message (a message
///   can quote a mood, a note, a reflection or a server reply);
/// - breadcrumbs from the fixed [CrashBreadcrumb] list;
/// - custom keys from the fixed [CrashKey] list, whose values are enum names.
/// There is no user identifier: the spec doesn't ask for one, so none is set.
///
/// Collection is off until allowed: the analytics consent (FR-ONB-03) in
/// every flavour, and in dev also `--dart-define=LW_CRASH_REPORTS=true`.

/// Breadcrumbs: event names only.
enum CrashBreadcrumb { appStarted, firebaseReady, devTestError }

/// Custom keys. Values are always an enum's name (see [CrashReporter.setKey]).
enum CrashKey { flavor }

/// Stands in for the real error in a report: only the type name is kept.
@immutable
class ScrubbedError implements Exception {
  const ScrubbedError(this.type);

  /// Builds the stand-in for [error]. Only the runtime type survives.
  factory ScrubbedError.of(Object error) =>
      ScrubbedError(error.runtimeType.toString());

  /// Dart runtime type name (code, never user data).
  final String type;

  @override
  String toString() => type;

  @override
  bool operator ==(Object other) =>
      other is ScrubbedError && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

/// Why an error was recorded. Fixed values only.
enum CrashReason { flutterError, uncaughtAsync, devTestError }

/// The raw crash backend (Crashlytics in the app, a fake in tests). Only
/// [CrashReporter] talks to it.
abstract class CrashSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> deleteUnsentReports();
  Future<void> recordError(
    ScrubbedError error,
    StackTrace? stack, {
    required CrashReason reason,
    required bool fatal,
  });
  Future<void> log(CrashBreadcrumb breadcrumb);
  Future<void> setKey(CrashKey key, String value);
}

class FirebaseCrashSink implements CrashSink {
  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _c.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> deleteUnsentReports() => _c.deleteUnsentReports();

  @override
  Future<void> recordError(
    ScrubbedError error,
    StackTrace? stack, {
    required CrashReason reason,
    required bool fatal,
  }) => _c.recordError(
    error,
    stack,
    reason: reason.name,
    fatal: fatal,
    // The plugin would otherwise print the details again on its own.
    printDetails: false,
  );

  @override
  Future<void> log(CrashBreadcrumb breadcrumb) => _c.log(breadcrumb.name);

  @override
  Future<void> setKey(CrashKey key, String value) =>
      _c.setCustomKey(key.name, value);
}

/// The only way app code reports crashes. Drops everything while
/// collection isn't allowed.
class CrashReporter {
  CrashReporter(this._sink);

  final CrashSink _sink;
  bool _enabled = false;
  bool _installed = false;
  StreamSubscription<bool>? _follow;
  final _keys = <CrashKey, String>{};

  /// True once collection is allowed (consent given, see top of file).
  bool get enabled => _enabled;

  /// Sends Flutter framework errors and uncaught async errors here. Errors
  /// are still printed to the console as before (debug builds).
  /// Safe to call again (a startup retry): installs once.
  void install() {
    if (_installed) return;
    _installed = true;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      (previous ?? FlutterError.presentError)(details);
      unawaited(
        recordError(
          details.exception,
          details.stack,
          reason: CrashReason.flutterError,
          fatal: !details.silent,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        recordError(
          error,
          stack,
          reason: CrashReason.uncaughtAsync,
          fatal: true,
        ),
      );
      return true;
    };
  }

  /// Switches collection to follow [allowed] (see [crashCollectionAllowed]).
  void follow(Stream<bool> allowed) {
    _follow?.cancel();
    _follow = allowed.distinct().listen(
      setEnabled,
      // Unknown means not allowed.
      onError: (Object _) => setEnabled(false),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _sink.setCollectionEnabled(enabled);
      // Reports cached while it was off (native crashes) are dropped, not
      // sent later.
      if (!enabled) await _sink.deleteUnsentReports();
      if (enabled) {
        for (final e in _keys.entries) {
          await _sink.setKey(e.key, e.value);
        }
      }
    } catch (_) {
      // Crash reporting must never break the app.
    }
  }

  /// Records [error] as its type name and stack trace only.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required CrashReason reason,
    bool fatal = false,
  }) async {
    if (!_enabled) return;
    try {
      await _sink.recordError(
        ScrubbedError.of(error),
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {}
  }

  Future<void> breadcrumb(CrashBreadcrumb b) async {
    if (!_enabled) return;
    try {
      await _sink.log(b);
    } catch (_) {}
  }

  /// Values are enum names (e.g. a [Flavor]), so free text can't be passed.
  /// Kept and sent once collection is on.
  Future<void> setKey(CrashKey key, Enum value) async {
    _keys[key] = value.name;
    if (!_enabled) return;
    try {
      await _sink.setKey(key, value.name);
    } catch (_) {}
  }

  void dispose() => _follow?.cancel();
}

/// `--dart-define=LW_CRASH_REPORTS=true`: lets a dev build report (still
/// only with the analytics consent). Off by default.
const devCrashReportsOptIn = bool.fromEnvironment('LW_CRASH_REPORTS');

/// Whether crash collection is allowed, live. Never on without the analytics
/// consent; signed out (no consent to read) means off. In dev also needs
/// [devOptIn]. [consents] is read only while signed in.
Stream<bool> crashCollectionAllowed({
  required Flavor flavor,
  required bool devOptIn,
  required Stream<bool> signedIn,
  required Stream<List<ConsentRecord>> Function() consents,
}) {
  if (flavor == Flavor.dev && !devOptIn) return Stream.value(false);
  // Switch, not asyncExpand: a sign-out must turn collection off at once,
  // even while the consent listener is still open (offline, it may never
  // end on its own).
  return _switchLatest(
    signedIn.distinct(),
    (inNow) => inNow
        ? consents().map(
            (r) => isGranted(currentConsents(r), ConsentType.analytics),
          )
        : Stream.value(false),
  );
}

/// Follows the stream made from the latest [outer] value only, cancelling
/// the previous one (rxdart's switchMap, without the dependency).
Stream<R> _switchLatest<T, R>(Stream<T> outer, Stream<R> Function(T) inner) {
  late StreamController<R> out;
  StreamSubscription<T>? outerSub;
  StreamSubscription<R>? innerSub;
  var outerDone = false;
  out = StreamController<R>(
    onListen: () {
      outerSub = outer.listen(
        (v) {
          innerSub?.cancel();
          innerSub = inner(v).listen(
            out.add,
            onError: out.addError,
            onDone: () {
              innerSub = null;
              if (outerDone) out.close();
            },
          );
        },
        onError: out.addError,
        onDone: () {
          outerDone = true;
          if (innerSub == null) out.close();
        },
      );
    },
    onCancel: () async {
      await innerSub?.cancel();
      await outerSub?.cancel();
    },
  );
  return out.stream;
}

final crashSinkProvider = Provider<CrashSink>((ref) => FirebaseCrashSink());

final crashReporterProvider = Provider<CrashReporter>((ref) {
  final r = CrashReporter(ref.watch(crashSinkProvider));
  ref.onDispose(r.dispose);
  return r;
});
