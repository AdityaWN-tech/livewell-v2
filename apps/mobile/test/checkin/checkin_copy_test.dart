import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The supportive lines on Home come from a fixed, reviewed list in
/// content/copy/checkin_responses.md (T-DLY-02). The app's ARB must hold
/// exactly the same texts.
void main() {
  test('ARB response lines match content/copy/checkin_responses.md', () {
    final md = File('../../content/copy/checkin_responses.md')
        .readAsStringSync();
    final fromContent = {
      for (final m in RegExp(
        r'^- (\w+): "(.*)"$',
        multiLine: true,
      ).allMatches(md))
        m.group(1)!: m.group(2)!,
    };
    expect(fromContent.keys, [
      'checkinResponseHigh',
      'checkinResponseSteady',
      'checkinResponseGentle',
    ]);
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    for (final e in fromContent.entries) {
      expect(arb[e.key], e.value, reason: e.key);
    }
  });
}
