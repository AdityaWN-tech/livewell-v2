import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/flavor.dart';
import '../domain/coach_message.dart';
import '../domain/moment_builder.dart';
import '../domain/moment_templates.dart';

/// The Avatar Moment builder with the bundled scripts (a copy of
/// content/coach/moments, checked by a test). Prod and staging use approved
/// scripts only; the dev build may use pending ones (T-DLY-03a).
final momentBuilderProvider = FutureProvider<MomentBuilder>((ref) async {
  final templates = [
    for (final m in Moment.scripted)
      MomentTemplate.parse(
        await rootBundle.loadString(
          'assets/coach/moments/${m.file}.json',
          cache: false,
        ),
      ),
  ];
  return MomentBuilder(
    templates,
    approvedOnly: ref.watch(flavorProvider) != Flavor.dev,
  );
});
