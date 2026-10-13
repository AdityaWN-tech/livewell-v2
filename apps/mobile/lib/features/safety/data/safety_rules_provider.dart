import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/safety_rules.dart';

const safetyRulesAsset = 'assets/safety/rules.json';

/// The bundled red-flag rules. Bundled (not downloaded) so they work offline
/// and can never be missing when a red flag appears.
final safetyRulesProvider = FutureProvider<SafetyRules>((ref) async {
  // cache: false: loaded once per app run anyway, and the shared bundle cache
  // can hand a stale future to a later test zone.
  final raw = await rootBundle.loadString(safetyRulesAsset, cache: false);
  return SafetyRules.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
