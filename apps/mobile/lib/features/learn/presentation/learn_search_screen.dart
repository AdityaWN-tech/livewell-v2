import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/learn_data.dart';
import '../domain/lesson.dart';
import 'learn_screen.dart';

/// Searches the approved lessons and audio sessions already on the phone
/// by title, summary or category (T-UI-02f). Nothing typed here is saved
/// or sent anywhere.
class LearnSearchScreen extends ConsumerStatefulWidget {
  const LearnSearchScreen({super.key});

  @override
  ConsumerState<LearnSearchScreen> createState() => _LearnSearchScreenState();
}

/// Lessons matching every word of [query], ignoring case.
List<Lesson> searchLessons(List<Lesson> all, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final x in all)
      if (words.every(
        (w) => '${x.title} ${x.summary ?? ''} ${x.category}'
            .toLowerCase()
            .contains(w),
      ))
        x,
  ];
}

class _LearnSearchScreenState extends ConsumerState<LearnSearchScreen> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final all = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final query = _text.text.trim();
    final found = searchLessons(all, query);
    final lessons = [
      for (final x in found)
        if (x.kind == LessonKind.lesson) x,
    ];
    final audio = [
      for (final x in found)
        if (x.kind == LessonKind.audio) x,
    ];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwPageTitle(l.learnSearch),
          TextField(
            key: const Key('learn-search-field'),
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.learnSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: LwSpacing.md),
          if (query.isEmpty)
            Text(l.learnSearchStart, style: t.bodyMedium)
          else if (found.isEmpty)
            Text(
              l.learnSearchEmpty(query),
              key: const Key('learn-search-empty'),
              style: t.bodyMedium,
            )
          else ...[
            if (lessons.isNotEmpty) LessonGrid(lessons),
            if (lessons.isNotEmpty && audio.isNotEmpty)
              const SizedBox(height: LwSpacing.sm),
            for (final a in audio)
              Padding(
                padding: const EdgeInsets.only(bottom: LwSpacing.sm),
                child: AudioRow(a),
              ),
          ],
        ],
      ),
    );
  }
}
