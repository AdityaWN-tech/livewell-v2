import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Startup timing markers for measuring NFR-01 (cold start to Home < 2.0 s)
/// from logcat timestamps. Printed in debug and profile builds only.
abstract final class StartupTrace {
  static void mark(String name) {
    if (!kReleaseMode) debugPrint('LW_STARTUP $name');
  }
}

/// A short, data-free code for a startup failure ("FirebaseException:unavailable").
String startupErrorCode(Object e) {
  if (e is ProviderException) {
    return 'ProviderException>${startupErrorCode(e.exception)}';
  }
  final code = switch (e) {
    FirebaseException(:final code) => ':$code',
    _ => '',
  };
  return '${e.runtimeType}$code';
}
