import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../data/content_repository.dart';
import '../domain/content.dart';
import '../domain/content_check.dart';

String _me(WidgetRef ref) => ref.read(sessionProvider).value?.uid ?? '';

Future<bool> _run(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That did not work. Try again.')),
    );
    return false;
  }
}

Widget _stateChip(BuildContext context, ReviewState s) =>
    Chip(label: Text(s.label), visualDensity: VisualDensity.compact);

/// Lessons, courses and the review queue (D-113/D-114).
class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value?.uid;
    final waiting = [
      ...?ref.watch(lessonsProvider).value?.map((l) => (l.state, l.authorUid)),
      ...?ref.watch(coursesProvider).value?.map((c) => (c.state, c.authorUid)),
    ].where((x) => x.$1 == ReviewState.pending && x.$2 != me).length;
    final superadmin = ref.watch(sessionProvider).value?.superadmin ?? false;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: AdminScaffold(
        title: 'Content',
        actions: [
          if (superadmin)
            TextButton(
              key: const Key('open-superadmin'),
              onPressed: () => context.go('/superadmin'),
              child: const Text('Superadmin'),
            ),
        ],
        body: Column(
          children: [
            TabBar(
              tabs: [
                const Tab(key: Key('tab-lessons'), text: 'Lessons'),
                const Tab(key: Key('tab-courses'), text: 'Courses'),
                Tab(
                  key: const Key('tab-review'),
                  text: waiting == 0 ? 'Review' : 'Review ($waiting)',
                ),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_LessonList(), _CourseList(), _ReviewList()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListShell extends StatelessWidget {
  const _ListShell({
    required this.newKey,
    required this.newLabel,
    required this.onNew,
    required this.children,
    required this.empty,
  });
  final String newKey;
  final String newLabel;
  final VoidCallback onNew;
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(LwSpacing.md),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: Key(newKey),
          onPressed: onNew,
          icon: const Icon(Icons.add),
          label: Text(newLabel),
        ),
      ),
      const SizedBox(height: LwSpacing.sm),
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.all(LwSpacing.lg),
          child: Text(empty, textAlign: TextAlign.center),
        ),
      ...children,
    ],
  );
}

class _LessonList extends ConsumerWidget {
  const _LessonList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(lessonsProvider).value ?? const [];
    return _ListShell(
      newKey: 'new-lesson',
      newLabel: 'New lesson',
      onNew: () => context.go('/content/lessons/new'),
      empty: 'No lessons yet. Write the first one.',
      children: [
        for (final l in list)
          ListTile(
            key: Key('lesson-${l.id}'),
            leading: Icon(l.audio ? Icons.air : Icons.menu_book_outlined),
            title: Text(l.title),
            subtitle: Text('${l.category} · version ${l.version}'),
            trailing: _stateChip(context, l.state),
            onTap: () => context.go('/content/lessons/${l.id}'),
          ),
      ],
    );
  }
}

class _CourseList extends ConsumerWidget {
  const _CourseList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(coursesProvider).value ?? const [];
    return _ListShell(
      newKey: 'new-course',
      newLabel: 'New course',
      onNew: () => context.go('/content/courses/new'),
      empty: 'No courses yet.',
      children: [
        for (final c in list)
          ListTile(
            key: Key('course-${c.id}'),
            leading: const Icon(Icons.school_outlined),
            title: Text(c.title),
            subtitle: Text(
              '${c.lessonIds.length} lessons · '
              '${c.visibility == CourseVisibility.all ? 'Everyone' : '${c.allowedEmails.length} chosen people'}',
            ),
            trailing: _stateChip(context, c.state),
            onTap: () => context.go('/content/courses/${c.id}'),
          ),
      ],
    );
  }
}

/// Items waiting for a second admin. Your own wait for someone else.
class _ReviewList extends ConsumerWidget {
  const _ReviewList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value?.uid;
    final lessons = (ref.watch(lessonsProvider).value ?? const [])
        .where((l) => l.state == ReviewState.pending)
        .toList();
    final courses = (ref.watch(coursesProvider).value ?? const [])
        .where((c) => c.state == ReviewState.pending)
        .toList();
    if (lessons.isEmpty && courses.isEmpty) {
      return const Center(child: Text('Nothing waiting for review.'));
    }
    Widget row(String key, String title, String author, String go) => ListTile(
      key: Key(key),
      title: Text(title),
      subtitle: Text(
        author == me
            ? 'Yours: waiting for another admin to review'
            : 'Open to review',
      ),
      onTap: () => context.go(go),
    );
    return ListView(
      padding: const EdgeInsets.all(LwSpacing.md),
      children: [
        for (final l in lessons)
          row(
            'review-lesson-${l.id}',
            'Lesson: ${l.title}',
            l.authorUid,
            '/content/lessons/${l.id}',
          ),
        for (final c in courses)
          row(
            'review-course-${c.id}',
            'Course: ${c.title}',
            c.authorUid,
            '/content/courses/${c.id}',
          ),
      ],
    );
  }
}

/// The review buttons for an item, by its state and who is looking.
class _ReviewBar extends ConsumerWidget {
  const _ReviewBar({
    required this.collection,
    required this.id,
    required this.state,
    required this.authorUid,
    required this.version,
    required this.text,
    required this.onSave,
  });

  final String collection;
  final String? id;
  final ReviewState state;
  final String authorUid;
  final int version;
  final String text;

  /// Saves the form; returns the id, or null when invalid.
  final Future<String?> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(contentRepositoryProvider);
    final me = ref.watch(sessionProvider).value?.uid;
    final issues = checkContent(text);
    final editable =
        state == ReviewState.draft || state == ReviewState.rejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (issues.isNotEmpty) ...[
          Card(
            key: const Key('content-issues'),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fix before review:'),
                  for (final i in issues) Text('• "${i.phrase}": ${i.why}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: LwSpacing.sm),
        ],
        Wrap(
          spacing: LwSpacing.xs,
          runSpacing: LwSpacing.xs,
          children: [
            if (editable) ...[
              OutlinedButton(
                key: const Key('content-save'),
                onPressed: () async {
                  final saved = await onSave();
                  if (saved != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Saved.')));
                  }
                },
                child: const Text('Save draft'),
              ),
              FilledButton(
                key: const Key('content-submit'),
                onPressed: issues.isNotEmpty
                    ? null
                    : () async {
                        final saved = await onSave();
                        if (saved == null || !context.mounted) return;
                        await _run(
                          context,
                          () => repo.submit(collection, saved),
                          'Sent for review. Another admin approves it.',
                        );
                      },
                child: const Text('Submit for review'),
              ),
            ],
            if (state == ReviewState.pending &&
                id != null &&
                authorUid != me) ...[
              OutlinedButton(
                key: const Key('content-reject'),
                onPressed: () => _run(
                  context,
                  () => repo.review(
                    collection,
                    id!,
                    approve: false,
                    uid: _me(ref),
                  ),
                  'Sent back to the author.',
                ),
                child: const Text('Send back'),
              ),
              FilledButton(
                key: const Key('content-approve'),
                onPressed: issues.isNotEmpty
                    ? null
                    : () => _run(
                        context,
                        () => repo.review(
                          collection,
                          id!,
                          approve: true,
                          uid: _me(ref),
                        ),
                        'Approved. It is live in the app.',
                      ),
                child: const Text('Approve'),
              ),
            ],
            if (state == ReviewState.pending && authorUid == me)
              const Text(
                'Waiting for another admin to review (2-person rule).',
              ),
            if (state == ReviewState.approved && id != null) ...[
              OutlinedButton(
                key: const Key('content-reopen'),
                onPressed: () => _run(
                  context,
                  () => repo.reopen(collection, id!, version),
                  'Back to draft as version ${version + 1}. It is hidden until approved again.',
                ),
                child: const Text('Edit (new version)'),
              ),
              OutlinedButton(
                key: const Key('content-retire'),
                onPressed: () => _run(
                  context,
                  () => repo.retire(collection, id!),
                  'Retired. It no longer shows in the app.',
                ),
                child: const Text('Retire'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: title,
    leading: IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/content'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(LwSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AdminLayout.narrowPageWidth * 1.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

String? _required(String? v) =>
    (v ?? '').trim().isEmpty ? 'This is needed.' : null;

/// Write or review one lesson or breathing session.
class LessonEditorScreen extends ConsumerStatefulWidget {
  const LessonEditorScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<LessonEditorScreen> createState() => _LessonEditorState();
}

class _LessonEditorState extends ConsumerState<LessonEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _summary = TextEditingController();
  final _cards = TextEditingController();
  final _habit = TextEditingController();
  final _habitMinutes = TextEditingController();
  bool _audio = false;
  String? _breathing;
  String? _id;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    for (final c in [_title, _summary, _cards, _habit]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _category,
      _summary,
      _cards,
      _habit,
      _habitMinutes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(LessonDoc l) {
    if (_loaded) return;
    _loaded = true;
    _title.text = l.title;
    _category.text = l.category;
    _summary.text = l.summary;
    _cards.text = l.cards.join('\n\n');
    _habit.text = l.microhabitTitle;
    _habitMinutes.text = l.microhabitMinutes?.toString() ?? '';
    _audio = l.audio;
    _breathing = l.breathing;
  }

  LessonDoc _doc(LessonDoc? from) => LessonDoc(
    id: _id,
    audio: _audio,
    title: _title.text,
    category: _category.text,
    summary: _summary.text,
    cards: _cards.text.split(RegExp(r'\n\s*\n')),
    microhabitTitle: _habit.text,
    microhabitMinutes: int.tryParse(_habitMinutes.text.trim()),
    breathing: _audio ? (_breathing ?? 'calm') : null,
    state: from?.state ?? ReviewState.draft,
    authorUid: from?.authorUid ?? '',
    version: from?.version ?? 1,
  );

  Future<String?> _save(LessonDoc? from) async {
    if (!_form.currentState!.validate()) return null;
    try {
      final id = await ref
          .read(contentRepositoryProvider)
          .saveLesson(_doc(from), uid: _me(ref));
      if (mounted) setState(() => _id = id);
      return id;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not saved. Try again.')));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _id == null
        ? null
        : ref
              .watch(lessonsProvider)
              .value
              ?.where((l) => l.id == _id)
              .firstOrNull;
    if (current != null) _load(current);
    final state = current?.state ?? ReviewState.draft;
    final editable =
        state == ReviewState.draft || state == ReviewState.rejected;
    final doc = _doc(current);
    return _Page(
      title: _id == null ? 'New lesson' : 'Lesson · ${state.label}',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const Key('lesson-audio'),
                title: const Text('Breathing session (not a reading lesson)'),
                value: _audio,
                onChanged: editable ? (v) => setState(() => _audio = v) : null,
              ),
              TextFormField(
                key: const Key('lesson-title'),
                controller: _title,
                enabled: editable,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _required,
              ),
              TextFormField(
                key: const Key('lesson-category'),
                controller: _category,
                enabled: editable,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'For example: Sleep, Movement, Food, Stress',
                ),
                validator: _required,
              ),
              TextFormField(
                key: const Key('lesson-summary'),
                controller: _summary,
                enabled: editable,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Short summary'),
              ),
              if (_audio)
                DropdownButtonFormField<String>(
                  key: const Key('lesson-breathing'),
                  initialValue: _breathing ?? 'calm',
                  decoration: const InputDecoration(
                    labelText: 'Breathing pattern',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'box',
                      child: Text('Box breathing'),
                    ),
                    DropdownMenuItem(value: 'calm', child: Text('Calm')),
                    DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
                  ],
                  onChanged: editable
                      ? (v) => setState(() => _breathing = v)
                      : null,
                )
              else ...[
                TextFormField(
                  key: const Key('lesson-cards'),
                  controller: _cards,
                  enabled: editable,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Cards',
                    helperText: 'One short paragraph per card. Leave an empty line between cards.',
                  ),
                  validator: (v) => _audio ? null : _required(v),
                ),
                TextFormField(
                  key: const Key('lesson-habit'),
                  controller: _habit,
                  enabled: editable,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Microhabit to try today (optional)',
                  ),
                ),
                TextFormField(
                  key: const Key('lesson-habit-minutes'),
                  controller: _habitMinutes,
                  enabled: editable,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes (optional)',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: LwSpacing.md),
        _ReviewBar(
          collection: lessonsCollection,
          id: _id,
          state: state,
          authorUid: current?.authorUid ?? _me(ref),
          version: current?.version ?? 1,
          text: doc.allText,
          onSave: () => _save(current),
        ),
      ],
    );
  }
}

/// Build or review a course: its lessons, in order, and who sees it.
class CourseEditorScreen extends ConsumerStatefulWidget {
  const CourseEditorScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorState();
}

class _CourseEditorState extends ConsumerState<CourseEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _summary = TextEditingController();
  final _emails = TextEditingController();
  List<String> _lessons = [];
  CourseVisibility _visibility = CourseVisibility.all;
  String? _id;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    for (final c in [_title, _summary]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _category, _summary, _emails]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(CourseDoc c) {
    if (_loaded) return;
    _loaded = true;
    _title.text = c.title;
    _category.text = c.category;
    _summary.text = c.summary;
    _emails.text = c.allowedEmails.join('\n');
    _lessons = [...c.lessonIds];
    _visibility = c.visibility;
  }

  CourseDoc _doc(CourseDoc? from) => CourseDoc(
    id: _id,
    title: _title.text,
    category: _category.text,
    summary: _summary.text,
    lessonIds: _lessons,
    visibility: _visibility,
    allowedEmails: _emails.text.split(RegExp(r'[\s,;]+')),
    state: from?.state ?? ReviewState.draft,
    authorUid: from?.authorUid ?? '',
    version: from?.version ?? 1,
  );

  Future<String?> _save(CourseDoc? from) async {
    if (!_form.currentState!.validate()) return null;
    if (_lessons.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one lesson.')));
      return null;
    }
    try {
      final id = await ref
          .read(contentRepositoryProvider)
          .saveCourse(_doc(from), uid: _me(ref));
      if (mounted) setState(() => _id = id);
      return id;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not saved. Try again.')));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _id == null
        ? null
        : ref
              .watch(coursesProvider)
              .value
              ?.where((c) => c.id == _id)
              .firstOrNull;
    if (current != null) _load(current);
    final state = current?.state ?? ReviewState.draft;
    final editable =
        state == ReviewState.draft || state == ReviewState.rejected;
    final live = (ref.watch(lessonsProvider).value ?? const [])
        .where((l) => l.state == ReviewState.approved)
        .toList();
    return _Page(
      title: _id == null ? 'New course' : 'Course · ${state.label}',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('course-title'),
                controller: _title,
                enabled: editable,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _required,
              ),
              TextFormField(
                key: const Key('course-category'),
                controller: _category,
                enabled: editable,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: _required,
              ),
              TextFormField(
                key: const Key('course-summary'),
                controller: _summary,
                enabled: editable,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Short summary'),
              ),
              const SizedBox(height: LwSpacing.sm),
              Text(
                'Lessons (in this order)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (live.isEmpty)
                const Text(
                  'No live lessons yet. A lesson must be approved before it can go in a course.',
                ),
              for (final l in live)
                CheckboxListTile(
                  key: Key('course-pick-${l.id}'),
                  value: _lessons.contains(l.id),
                  title: Text(l.title),
                  subtitle: _lessons.contains(l.id)
                      ? Text('Lesson ${_lessons.indexOf(l.id!) + 1}')
                      : null,
                  onChanged: editable
                      ? (on) => setState(() {
                          if (on ?? false) {
                            _lessons = [..._lessons, l.id!];
                          } else {
                            _lessons = _lessons
                                .where((x) => x != l.id)
                                .toList();
                          }
                        })
                      : null,
                ),
              const SizedBox(height: LwSpacing.sm),
              Text(
                'Who can see it',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              RadioGroup<CourseVisibility>(
                groupValue: _visibility,
                onChanged: (v) {
                  if (editable && v != null) setState(() => _visibility = v);
                },
                child: const Column(
                  children: [
                    RadioListTile(
                      key: Key('course-all'),
                      value: CourseVisibility.all,
                      title: Text('Everyone'),
                    ),
                    RadioListTile(
                      key: Key('course-selected'),
                      value: CourseVisibility.selected,
                      title: Text('Only the people I choose'),
                    ),
                  ],
                ),
              ),
              if (_visibility == CourseVisibility.selected)
                TextFormField(
                  key: const Key('course-emails'),
                  controller: _emails,
                  enabled: editable,
                  minLines: 3,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Their sign-in emails',
                    helperText: 'One per line. They see the course when signed in with that email.',
                  ),
                  validator: (v) =>
                      _visibility == CourseVisibility.selected &&
                          (v ?? '').trim().isEmpty
                      ? 'Add at least one email.'
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: LwSpacing.md),
        _ReviewBar(
          collection: coursesCollection,
          id: _id,
          state: state,
          authorUid: current?.authorUid ?? _me(ref),
          version: current?.version ?? 1,
          text: _doc(current).allText,
          onSave: () => _save(current),
        ),
      ],
    );
  }
}
