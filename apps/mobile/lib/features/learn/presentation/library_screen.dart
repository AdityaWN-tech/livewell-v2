import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/learn_data.dart';
import '../domain/lesson.dart';
import 'learn_screen.dart';

/// Every approved lesson ("See all" on Learn).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = [
      for (final x in ref.watch(lessonsProvider).value ?? const <Lesson>[])
        if (x.kind == LessonKind.lesson) x,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).learnLibraryTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [LessonGrid(lessons)],
      ),
    );
  }
}
