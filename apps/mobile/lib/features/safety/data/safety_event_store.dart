import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dev/application/preview_mode.dart';

/// On this phone only: when a red flag was last shown (a safety response
/// in the check-in). Only the time is kept: no text, no category, nothing
/// sent anywhere (D-70). It survives a restart, so the coach stays quiet for
/// the rest of that day and portal cards stay off for 72 hours (AGENTS.md,
/// FR-SAF-07), on top of the server-side record still to come (D-22).
abstract class SafetyEventStore {
  Future<DateTime?> lastEventAt();
  Future<void> recordEvent(DateTime at);
}

class SharedPrefsSafetyEventStore implements SafetyEventStore {
  static const _key = 'safety_last_event_at_v1';

  @override
  Future<DateTime?> lastEventAt() async {
    final ms = (await SharedPreferences.getInstance()).getInt(_key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> recordEvent(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    final earlier = prefs.getInt(_key);
    // Keep the latest time only.
    if (earlier == null || at.millisecondsSinceEpoch > earlier) {
      await prefs.setInt(_key, at.millisecondsSinceEpoch);
    }
  }
}

/// Preview mode and tests: kept in memory.
class InMemorySafetyEventStore implements SafetyEventStore {
  InMemorySafetyEventStore([this.last]);

  DateTime? last;

  @override
  Future<DateTime?> lastEventAt() async => last;

  @override
  Future<void> recordEvent(DateTime at) async {
    if (last == null || at.isAfter(last!)) last = at;
  }
}

final safetyEventStoreProvider = Provider<SafetyEventStore>((ref) {
  if (ref.watch(previewModeProvider)) return InMemorySafetyEventStore();
  return SharedPrefsSafetyEventStore();
});
