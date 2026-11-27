import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/tokens.dart';
import '../../../core/widgets/admin_scaffold.dart';
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

String _when(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';

/// The Superadmin portal (D-112): access requests, Admins and the log.
class SuperadminScreen extends ConsumerWidget {
  const SuperadminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_requestsProvider).value?.length ?? 0;
    return DefaultTabController(
      length: 3,
      child: AdminScaffold(
        title: 'Superadmin',
        actions: [
          TextButton(
            key: const Key('open-catalog'),
            onPressed: () => context.go('/offers'),
            child: const Text('Admin console'),
          ),
        ],
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(
                  key: const Key('tab-requests'),
                  text: pending == 0 ? 'Requests' : 'Requests ($pending)',
                ),
                const Tab(key: Key('tab-admins'), text: 'Admins'),
                const Tab(key: Key('tab-activity'), text: 'Activity'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_RequestsTab(), _AdminsTab(), _ActivityTab()],
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
    final async = ref.watch(_requestsProvider);
    final list = async.value;
    if (list == null) {
      return async.hasError
          ? const _Empty('Requests could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) return const _Empty('No requests waiting.');
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
                onPressed: () => _act(
                  context,
                  () => repo.reject(r, superUid: me),
                  '${r.name}’s request was declined.',
                ),
                child: const Text('Reject'),
              ),
              FilledButton(
                key: Key('approve-${r.uid}'),
                onPressed: () => _act(
                  context,
                  () => repo.approve(r, superUid: me),
                  '${r.name} is now an Admin.',
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
    final async = ref.watch(_membersProvider);
    final list = async.value;
    if (list == null) {
      return async.hasError
          ? const _Empty('Admins could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) return const _Empty('No Admins yet.');
    return ListView.separated(
      padding: const EdgeInsets.all(LwSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final m = list[i];
        return ListTile(
          key: Key('member-${m.uid}'),
          title: Text('${m.name} (${m.email})'),
          subtitle: Text(m.active ? 'Admin' : 'Removed'),
          trailing: m.active
              ? OutlinedButton(
                  key: Key('remove-${m.uid}'),
                  onPressed: () => _act(
                    context,
                    () => repo.setActive(m, active: false, superUid: me),
                    '${m.name} is no longer an Admin.',
                  ),
                  child: const Text('Remove'),
                )
              : TextButton(
                  key: Key('restore-${m.uid}'),
                  onPressed: () => _act(
                    context,
                    () => repo.setActive(m, active: true, superUid: me),
                    '${m.name} is an Admin again.',
                  ),
                  child: const Text('Restore'),
                ),
        );
      },
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activityProvider);
    final list = async.value;
    if (list == null) {
      return async.hasError
          ? const _Empty('The log could not be loaded.')
          : const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) return const _Empty('Nothing has happened yet.');
    return ListView.builder(
      padding: const EdgeInsets.all(LwSpacing.md),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final e = list[i];
        return ListTile(
          dense: true,
          title: Text('${e.label}: ${e.target}'),
          subtitle: Text('${_when(e.at)} · by ${e.actor}'),
        );
      },
    );
  }
}
