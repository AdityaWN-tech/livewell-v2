import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../core/design/illustration/illustration.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../moments/application/moment_context.dart';
import '../../moments/data/coach_speaker.dart';
import '../../moments/domain/coach_message.dart';
import '../../voice/presentation/voice_screen.dart' show AiVoiceLabel;
import '../application/learn_data.dart';
import '../data/learn_repository.dart';
import '../domain/lesson.dart';
import 'breathing_screen.dart';

/// Opens one approved item by id (`/learn/item/:id`): a lesson in the
/// reader, a breathing session in the breathing guide.
class LearnItemScreen extends ConsumerWidget {
  const LearnItemScreen({super.key, required this.id});

  static String pathFor(String id) => '/learn/item/${Uri.encodeComponent(id)}';

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(lessonsProvider).hasValue;
    final progress = ref.watch(contentProgressProvider);
    final lesson = ref.watch(lessonByIdProvider(id));
    if (!loaded ||
        (lesson != null && !progress.hasValue && !progress.hasError)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (lesson == null) return const _Missing();
    if (lesson.kind == LessonKind.audio) {
      return BreathingScreen(
        pattern: lesson.breathing,
        minutes: lesson.readMinutes,
        item: lesson,
      );
    }
    return LessonReaderScreen(
      lesson: lesson,
      startProgress: progress.value?[lesson.id]?.progress ?? 0,
    );
  }
}

/// The lesson reader (FR-LRN-01/02, Step 4e): the lesson's short cards one
/// at a time, ending with its MY GOAL DO IT microhabit. Where the person is
/// is saved (offline too) for "Pick up where you left off". "Listen" has
/// the coach read the cards aloud in the chosen voice, with a progress bar
/// and the AI voice label; only the approved card text is spoken, each
/// line with its own message id (closed-script rule, FR-VOC-05).
class LessonReaderScreen extends ConsumerStatefulWidget {
  const LessonReaderScreen({
    super.key,
    required this.lesson,
    this.startProgress = 0,
  });

  final Lesson lesson;

  /// Saved progress (0..1): the reader opens on that card.
  final double startProgress;

  @override
  ConsumerState<LessonReaderScreen> createState() => _LessonReaderState();
}

class _LessonReaderState extends ConsumerState<LessonReaderScreen> {
  Lesson get _lesson => widget.lesson;

  /// The cards, then the end page.
  int get _pages => _lesson.cards.length + 1;
  bool get _onEnd => _page == _pages - 1;

  /// Progress is saved as (page + 1) / pages; a finished lesson starts
  /// again from the first card.
  late int _page = widget.startProgress >= 1
      ? 0
      : ((widget.startProgress * _pages).round() - 1).clamp(0, _pages - 1);
  late final PageController _pager = PageController(initialPage: _page);

  /// Read once: the speaker is stopped while the screen closes, when ref
  /// can't be used any more.
  late final CoachSpeaker _speaker;
  late final LearnRepository _learn;

  bool _listening = false;

  /// 0..1 through the card being read.
  double _spoken = 0;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(coachSpeakerProvider);
    _learn = ref.read(learnRepositoryProvider);
  }

  @override
  void dispose() {
    if (_listening) _speaker.stop();
    _pager.dispose();
    super.dispose();
  }

  void _save({bool completed = false}) => _learn.saveProgress(
    _lesson.id,
    progress: completed ? 1 : (_page + 1) / _pages,
    completed: completed,
  );

  void _onPage(int page) {
    setState(() {
      _page = page;
      _spoken = 0;
    });
    _save();
    if (_listening) _speakPage();
  }

  void _go(int page) {
    final d = LwMotion.duration(context, LwMotion.medium);
    if (d == Duration.zero) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(page, duration: d, curve: LwMotion.curve);
    }
  }

  /// The approved line for [page]: a card, or the microhabit at the end.
  CoachMessage? _lineFor(int page) {
    final x = _lesson;
    final String text;
    final String part;
    if (page < x.cards.length) {
      text = x.cards[page];
      part = 'c${page + 1}';
    } else if (x.microhabit != null) {
      text = x.microhabit!.title;
      part = 'habit';
    } else {
      return null;
    }
    return CoachMessage(
      messageId: 'lesson.${x.id}.$part@v${x.version}',
      moment: Moment.lesson,
      text: text,
      emotion: CoachEmotion.calm,
      primaryAction: MomentAction.close,
      secondaryActions: const [],
      containsUserText: false,
      approved: true,
    );
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      setState(() => _listening = false);
      await _speaker.stop();
      return;
    }
    setState(() => _listening = true);
    await _speakPage();
  }

  Future<void> _speakPage() async {
    final page = _page;
    final line = _lineFor(page);
    if (line == null) {
      setState(() => _listening = false);
      return;
    }
    final speed = await ref.read(coachVoiceSpeedProvider.future);
    if (!mounted || !_listening || page != _page) return;
    final ok = await _speaker.speak(
      line,
      speed: speed,
      onWord: (_, end) {
        if (!mounted || page != _page) return;
        setState(() => _spoken = (end / line.text.length).clamp(0, 1));
      },
      onDone: () {
        if (!mounted || !_listening || page != _page) return;
        setState(() => _spoken = 1);
        if (page < _pages - 1) {
          _go(page + 1);
        } else {
          setState(() => _listening = false);
        }
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).learnListenUnavailable),
        ),
      );
    }
  }

  void _finish() {
    _save(completed: true);
    if (_listening) _speaker.stop();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final cards = _lesson.cards.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson.category),
        actions: [
          IconButton(
            key: const Key('lesson-listen'),
            tooltip: _listening ? l.learnListenStop : l.learnListen,
            onPressed: _toggleListen,
            icon: Icon(
              _listening ? Icons.stop_circle_outlined : Icons.headphones,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_listening)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LwSpacing.screenGutter,
                  0,
                  LwSpacing.screenGutter,
                  LwSpacing.xs,
                ),
                child: Column(
                  key: const Key('lesson-listening'),
                  children: [
                    const AiVoiceLabel(),
                    const SizedBox(height: LwSpacing.xs),
                    Semantics(
                      label: l.learnListenProgress(
                        _page < cards ? _page + 1 : cards,
                        cards,
                      ),
                      child: ClipRRect(
                        borderRadius: LwRadius.pillAll,
                        child: LinearProgressIndicator(
                          value: _spoken,
                          minHeight: LwSpacing.xxs,
                          color: p.accent,
                          backgroundColor: p.surfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PageView.builder(
                key: const Key('lesson-pages'),
                controller: _pager,
                itemCount: _pages,
                onPageChanged: _onPage,
                itemBuilder: (context, i) => i < cards
                    ? _CardPage(lesson: _lesson, index: i)
                    : _EndPage(lesson: _lesson),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LwSpacing.screenGutter),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: LwRadius.pillAll,
                          child: LinearProgressIndicator(
                            value: (_page + 1) / _pages,
                            minHeight: LwSpacing.xxs,
                            color: p.primary,
                            backgroundColor: p.surfaceMuted,
                          ),
                        ),
                      ),
                      if (!_onEnd) ...[
                        const SizedBox(width: LwSpacing.sm),
                        Text(
                          l.learnReaderCardOf(_page + 1, cards),
                          key: const Key('lesson-card-of'),
                          style: t.labelMedium,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: LwSpacing.sm),
                  Row(
                    children: [
                      if (_page > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('lesson-back'),
                            onPressed: () => _go(_page - 1),
                            child: Text(l.learnReaderBack),
                          ),
                        ),
                        const SizedBox(width: LwSpacing.sm),
                      ],
                      Expanded(
                        child: _onEnd
                            ? FilledButton(
                                key: const Key('lesson-finish'),
                                onPressed: _finish,
                                child: Text(l.learnReaderFinish),
                              )
                            : FilledButton(
                                key: const Key('lesson-next'),
                                onPressed: () => _go(_page + 1),
                                child: Text(l.learnReaderNext),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPage extends StatelessWidget {
  const _CardPage({required this.lesson, required this.index});
  final Lesson lesson;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final x = lesson;
    return SingleChildScrollView(
      key: Key('lesson-card-$index'),
      padding: const EdgeInsets.symmetric(horizontal: LwSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (index == 0) ...[
            ClipRRect(
              borderRadius: LwRadius.lgAll,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Illustration(x.artId, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: LwSpacing.md),
            Text(x.title, style: t.headlineSmall),
            if (x.readMinutes != null)
              Text(l.learnMinutes(x.readMinutes!), style: t.labelMedium),
            if (x.summary != null) ...[
              const SizedBox(height: LwSpacing.xs),
              Text(x.summary!, style: t.bodyMedium),
            ],
            const SizedBox(height: LwSpacing.md),
          ] else
            const SizedBox(height: LwSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.lg),
              child: Text(x.cards[index], style: t.titleMedium),
            ),
          ),
          const SizedBox(height: LwSpacing.md),
        ],
      ),
    );
  }
}

/// The last page: the microhabit to try today, or a short well done.
class _EndPage extends StatelessWidget {
  const _EndPage({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final p = LwPalette.of(context);
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final habit = lesson.microhabit;
    return SingleChildScrollView(
      key: const Key('lesson-end'),
      padding: const EdgeInsets.all(LwSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LwSpacing.lg),
          Text(l.learnReaderEndTitle, style: t.headlineSmall),
          const SizedBox(height: LwSpacing.xs),
          Text(l.learnReaderEndBody, style: t.bodyMedium),
          if (habit != null) ...[
            const SizedBox(height: LwSpacing.lg),
            Material(
              key: const Key('lesson-microhabit'),
              color: p.mint,
              borderRadius: LwRadius.lgAll,
              child: Padding(
                padding: const EdgeInsets.all(LwSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.learnReaderTryThis.toUpperCase(),
                      style: t.labelMedium?.copyWith(color: p.onTintSecondary),
                    ),
                    const SizedBox(height: LwSpacing.xxs),
                    Text(
                      habit.title,
                      style: t.titleMedium?.copyWith(color: p.onTint),
                    ),
                    if (habit.minutes != null)
                      Text(
                        l.learnMinutes(habit.minutes!),
                        style: t.bodySmall?.copyWith(color: p.onTintSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The item isn't approved, can't open, or was removed: say so kindly and
/// go back to Learn (never a dead end).
class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        key: const Key('lesson-missing'),
        padding: const EdgeInsets.all(LwSpacing.screenGutter),
        children: [
          LwEmptyState(
            icon: Icons.menu_book_outlined,
            title: l.learnReaderMissingTitle,
            body: l.learnReaderMissingBody,
          ),
          FilledButton(
            onPressed: () => context.go('/learn'),
            child: Text(l.learnReaderBackToLearn),
          ),
        ],
      ),
    );
  }
}
