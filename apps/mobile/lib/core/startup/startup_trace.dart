import 'package:flutter/foundation.dart';

/// Startup timing markers for measuring NFR-01 (cold start to Home < 2.0 s)
/// from logcat timestamps. Printed in debug and profile builds only.
abstract final class StartupTrace {
  static void mark(String name) {
    if (!kReleaseMode) debugPrint('LW_STARTUP $name');
  }
}
