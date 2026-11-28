import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/staff.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/content.dart';
import '../data/staff_access_repository.dart';
import '../domain/staff_access.dart';

final _requestsProvider = StreamProvider<List<StaffRequest>>(
  (ref) => ref.watch(staffAccessRepositoryProvider).pendingRequests(),
);
final _membersProvider = StreamProvider<List<StaffMember>>(
  (ref) => ref.watch(staffAccessRepositoryProvider).members(),
);
final _activityProvider = StreamProvider<List<StaffAuditEntry>>(
  (ref) => ref.watch(staffAccessRepositoryProvider).activity(),
);
final _peopleProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(staffAccessRepositoryProvider).people(),
);

/// What the Superadmin typed in the search box (lower case).
class _Search extends Notifier<String> {
  @override
  String build() => '';

  void set(String v) => state = v.trim().toLowerCase();
}

final _searchProvider = NotifierProvider<_Search, String>(_Search.new);

String _when(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';

bool _matches(String query, Iterable<String> fields) =>
    query.isEmpty || fields.any((f) => f.toLowerCase().contains(query));

/// The Superadmin portal (D-112, D-118): access requests, Admins and their
/// roles, what content is waiting, and the activity log.
class SuperadminScreen extends ConsumerWidget {
  const SuperadminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_requestsProvider).value?.length ?? 0;
    return DefaultTabController(
      length: 4,
      child: AdminScaffold(
        title: 'Superadmin',
        actions: [
          TextButton(
            key: const Key('open-catalog'),
            onPressed: () => context.go('/content'),
            child: const Text('Admin console'),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LwSpacing.md,
                LwSpacing.sm,
                LwSpacing.md,
                0,
              ),
              child: TextField(
                key: const Key('staff-search'),
                decoration: const InputDecoration(
                  labelText: 'Search by name or email',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => ref.read(_searchProvider.notifier).set(v),
              ),
            ),
            TabBar(
              tabs: [
                Tab(
                  key: const Key('tab-requests'),
                  text: pending == 0 ? 'Requests' : 'Requests ($pending)',
                ),
                const Tab(key: Key('tab-admins'), text: 'Admins'),
                const Tab(key: Key('tab-content'), text: 'Content'),
                const Tab(key: Key('tab-activity'), text: 'Activity'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _RequestsTab(),
                  _AdminsTab(),
                  _ContentTab(),
                  _ActivityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs a Superadmin action and says plainly if it failed.
Future<void> _act(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That did not work. Try again.')),
    );
  }
}

/// Asks before a step that takes something away (reject, remove).
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: const Key('confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-ok'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(LwSpacing.lg),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value?.uid ?? '';
    final repo = ref.watch(staffAccessRepositoryProvider);
    final query = ref.watch(_searchProvider);
    final async = ref.watch(_requestsProvider);
    final all = async.value;
    if (all == null) {
      return async.hasError
          ? const _Empty('Requests could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (all.isEmpty) return const _Empty('No requests waiting.');
    final list = [
      for (final r in all)
        if (_matches(query, [r.name, r.email])) r,
    ];
    if (list.isEmpty) return const _Empty('No requests match your search.');
    return ListView.separated(
      padding: const EdgeInsets.all(LwSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final r = list[i];
        return ListTile(
          key: Key('request-${r.uid}'),
          title: Text('${r.name} (${r.email})'),
          subtitle: Text('${r.reason}\n${_when(r.createdAt)}'),
          isThreeLine: true,
          trailing: Wrap(
            spacing: LwSpacing.xs,
            children: [
              OutlinedButton(
                key: Key('reject-${r.uid}'),
                onPressed: () async {
                  final ok = await _confirm(
                    context,
                    title: 'Decline ${r.name}?',
                    body:
                        '${r.name} will not get the console. They can ask '
                        'again later.',
                    action: 'Decline',
                  );
                  if (!ok || !context.mounted) return;
                  await _act(
                    context,
                    () => repo.reject(r, superUid: me),
                    '${r.name}’s request was declined.',
                  );
                },
                child: const Text('Reject'),
              ),
              FilledButton(
                key: Key('approve-${r.uid}'),
                onPressed: () => _act(
                  context,
                  () => repo.approve(r, superUid: me),
                  '${r.name} is now an Admin (Content editor).',
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminsTab extends ConsumerWidget {
  const _AdminsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value?.uid ?? '';
    final repo = ref.watch(staffAccessRepositoryProvider);
    final query = ref.watch(_searchProvider);
    final async = ref.watch(_membersProvider);
    final all = async.value;
    if (all == null) {
      return async.hasError
          ? const _Empty('Admins could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (all.isEmpty) return const _Empty('No Admins yet.');
    final list = [
      for (final m in all)
        if (_matches(query, [m.name, m.email])) m,
    ];
    if (list.isEmpty) return const _Empty('No Admins match your search.');
    return ListView.separated(
      padding: const EdgeInsets.all(LwSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final m = list[i];
        return ListTile(
          key: Key('member-${m.uid}'),
          title: Text('${m.name} (${m.email})'),
          subtitle: Text(m.active ? m.rolesLabel : 'Removed'),
          trailing: Wrap(
            spacing: LwSpacing.xs,
            children: [
              if (m.active) ...[
                TextButton(
                  key: Key('roles-${m.uid}'),
                  onPressed: () async {
                    final roles = await showDialog<Set<StaffRole>>(
                      context: context,
                      builder: (_) => _RolesDialog(member: m),
                    );
                    if (roles == null || !context.mounted) return;
                    await _act(
                      context,
                      () => repo.setRoles(m, roles, superUid: me),
                      '${m.name}’s roles were saved.',
                    );
                  },
                  child: const Text('Roles'),
                ),
                OutlinedButton(
                  key: Key('remove-${m.uid}'),
                  onPressed: () async {
                    final ok = await _confirm(
                      context,
                      title: 'Remove ${m.name}?',
                      body:
                          '${m.name} loses the console straight away. You '
                          'can restore them later.',
                      action: 'Remove',
                    );
                    if (!ok || !context.mounted) return;
                    await _act(
                      context,
                      () => repo.setActive(m, active: false, superUid: me),
                      '${m.name} is no longer an Admin.',
                    );
                  },
                  child: const Text('Remove'),
                ),
              ] else
                TextButton(
                  key: Key('restore-${m.uid}'),
                  onPressed: () => _act(
                    context,
                    () => repo.setActive(m, active: true, superUid: me),
                    '${m.name} is an Admin again.',
                  ),
                  child: const Text('Restore'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tick the roles an Admin has (D-118).
class _RolesDialog extends StatefulWidget {
  const _RolesDialog({required this.member});
  final StaffMember member;

  @override
  State<_RolesDialog> createState() => _RolesDialogState();
}

class _RolesDialogState extends State<_RolesDialog> {
  late final Set<StaffRole> _roles = {...widget.member.roles};

  static String _help(StaffRole r) => switch (r) {
    StaffRole.contentEditor => 'Writes lessons, courses and questions.',
    StaffRole.clinicalReviewer =>
      'Approves or sends back what others wrote. Needed before anything '
          'goes live.',
    StaffRole.safetyReviewer => 'Checks content for safety (a label for now).',
    StaffRole.admin => '',
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Roles for ${widget.member.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in assignableRoles)
          CheckboxListTile(
            key: Key('role-${r.claim}'),
            value: _roles.contains(r),
            title: Text(r.label),
            subtitle: Text(_help(r)),
            onChanged: (v) =>
                setState(() => v ?? false ? _roles.add(r) : _roles.remove(r)),
          ),
      ],
    ),
    actions: [
      TextButton(
        key: const Key('roles-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('roles-save'),
        onPressed: () => Navigator.of(context).pop({..._roles}),
        child: const Text('Save'),
      ),
    ],
  );
}

/// What content is waiting for a clinical reviewer (D-114, D-118).
class _ContentTab extends ConsumerWidget {
  const _ContentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int waiting(List<ReviewState>? states) =>
        states?.where((s) => s == ReviewState.pending).length ?? 0;
    final rows = [
      (
        'lessons',
        'Lessons and audio',
        waiting(ref.watch(lessonsProvider).value?.map((l) => l.state).toList()),
      ),
      (
        'courses',
        'Courses',
        waiting(ref.watch(coursesProvider).value?.map((c) => c.state).toList()),
      ),
      (
        'drivers',
        'Live Well Map driver names',
        waiting(
          ref.watch(driverSetsProvider).value?.map((d) => d.state).toList(),
        ),
      ),
      (
        'questions',
        'Live Well Map questions',
        waiting(
          ref.watch(questionsProvider).value?.map((q) => q.state).toList(),
        ),
      ),
    ];
    final reviewers = (ref.watch(_membersProvider).value ?? const [])
        .where((m) => m.clinicalReviewer)
        .length;
    final total = rows.fold<int>(0, (sum, r) => sum + r.$3);
    return ListView(
      padding: const EdgeInsets.all(LwSpacing.md),
      children: [
        if (reviewers == 0)
          Card(
            key: const Key('no-reviewer'),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.md),
              child: Text(
                'No clinical reviewer yet. Nothing can go live until you '
                'give an Admin the Clinical reviewer role (Admins tab, '
                'Roles).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          )
        else
          ListTile(
            key: const Key('reviewer-count'),
            title: Text(
              reviewers == 1
                  ? '1 clinical reviewer'
                  : '$reviewers clinical reviewers',
            ),
          ),
        const Divider(),
        for (final (key, label, count) in rows)
          ListTile(
            key: Key('waiting-$key'),
            title: Text(label),
            trailing: Text(count == 0 ? 'Nothing waiting' : '$count waiting'),
          ),
        const SizedBox(height: LwSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('open-review'),
            onPressed: () => context.go('/content?tab=review'),
            child: Text(
              total == 0
                  ? 'Open the review queue'
                  : 'Open the review queue ($total)',
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value?.uid ?? '';
    final query = ref.watch(_searchProvider);
    final async = ref.watch(_activityProvider);
    final list = async.value;
    if (list == null) {
      return async.hasError
          ? const _Empty('The log could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) return const _Empty('Nothing has happened yet.');
    // Names from requests and members; ids only as a last resort.
    final names = <String, String>{
      ...?ref.watch(_peopleProvider).value,
      for (final m
          in ref.watch(_membersProvider).value ?? const <StaffMember>[])
        m.uid: '${m.name} (${m.email})',
    };
    String who(String uid) => names[uid] ?? 'Unknown person ($uid)';
    String by(String uid) =>
        uid == me ? 'you' : (names[uid] ?? 'another Superadmin');
    final shown = [
      for (final e in list)
        if (_matches(query, [who(uidOfTarget(e.target)), by(e.actor)])) e,
    ];
    if (shown.isEmpty) return const _Empty('Nothing matches your search.');
    return ListView.builder(
      padding: const EdgeInsets.all(LwSpacing.md),
      itemCount: shown.length,
      itemBuilder: (_, i) {
        final e = shown[i];
        return ListTile(
          key: Key('activity-$i'),
          dense: true,
          title: Text('${e.label}: ${who(uidOfTarget(e.target))}'),
          subtitle: Text('${_when(e.at)} · by ${by(e.actor)}'),
        );
      },
    );
  }
}
