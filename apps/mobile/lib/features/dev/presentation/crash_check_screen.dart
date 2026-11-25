import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/monitoring/crash_reporting.dart';

/// Developer > Crash reporting (dev flavour only, T-FND-10, D-80). Sends a
/// test error whose message looks like health data and free text, to check
/// in the Crashlytics console that only the type name and stack arrive
/// ("Test crash shows no PHI"). Reporting in dev needs
/// `--dart-define=LW_CRASH_REPORTS=true` and the analytics consent.
class CrashCheckScreen extends ConsumerWidget {
  const CrashCheckScreen({super.key});

  static const path = '/dev/crash-reporting';

  /// Made-up "PHI" that must NOT appear in the console.
  static const fakePhi = 'mood=2 sleep=4h note="I feel awful today"';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crash = ref.watch(crashReporterProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Crash reporting')),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          Text(
            crash.enabled
                ? 'Collection is ON.'
                : 'Collection is OFF (needs LW_CRASH_REPORTS=true in dev '
                      'and the analytics consent). Nothing will be sent.',
            key: const Key('crash-status'),
            style: t.bodyMedium,
          ),
          const SizedBox(height: LwSpacing.md),
          FilledButton(
            key: const Key('crash-send-test-error'),
            onPressed: () async {
              await crash.breadcrumb(CrashBreadcrumb.devTestError);
              await crash.recordError(
                StateError(fakePhi),
                StackTrace.current,
                reason: CrashReason.devTestError,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Test error sent')));
            },
            child: const Text('Send a test error'),
          ),
          const SizedBox(height: LwSpacing.xs),
          OutlinedButton(
            key: const Key('crash-throw-uncaught'),
            // Uncaught async error: goes through PlatformDispatcher.onError.
            onPressed: () => unawaited(
              Future<void>.error(StateError(fakePhi), StackTrace.current),
            ),
            child: const Text('Throw an uncaught error'),
          ),
          const SizedBox(height: LwSpacing.md),
          Text(
            'In the console the issue must read "StateError" with no '
            'message. If "$fakePhi" shows up anywhere, the scrubbing is '
            'broken: stop and report it.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
