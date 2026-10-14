import 'package:flutter_test/flutter_test.dart';

/// Advances fake time in 16 ms frames, like a real device, so animations
/// complete and timers they start get to run in order.
Future<void> pumpFrames(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(frame);
    elapsed += frame;
  }
}
