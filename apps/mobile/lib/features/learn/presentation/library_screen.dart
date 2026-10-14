import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/learn_data.dart';
import 'learn_screen.dart';

/// Every approved lesson ("View all" on Learn).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).learnLibraryTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        itemCount: lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: LwSpacing.sm),
        itemBuilder: (_, i) => LessonRow(lessons[i]),
      ),
    );
  }
}
