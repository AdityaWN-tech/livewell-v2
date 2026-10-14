import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" in the device's local time zone. Overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
