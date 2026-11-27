import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';
import '../data/staff_access_repository.dart';
import '../domain/staff_access.dart';

/// A narrow centred page with a heading, for the sign-in steps.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LwSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdminLayout.narrowPageWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: t.headlineSmall),
                ),
                const SizedBox(height: LwSpacing.sm),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Request admin access" (D-112): name and why, then a Superadmin decides.
class RequestAccessScreen extends ConsumerStatefulWidget {
  const RequestAccessScreen({super.key});

  @override
  ConsumerState<RequestAccessScreen> createState() =>
      _RequestAccessScreenState();
}

class _RequestAccessScreenState extends ConsumerState<RequestAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final session = ref.read(sessionProvider).value;
    if (_busy || session == null || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(staffAccessRepositoryProvider)
          .request(
            uid: session.uid,
            email: session.email ?? '',
            name: _name.text,
            reason: _reason.text,
            again: ref.read(staffAccessProvider).value == StaffAccess.rejected,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The request was not sent. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final rejected =
        ref.watch(staffAccessProvider).value == StaffAccess.rejected;
    return _StepPage(
      key: const Key('request-access'),
      title: 'Request admin access',
      children: [
        Text(
          rejected
              ? 'Your last request was not approved. You can ask again with '
                    'more detail.'
              : 'A Superadmin will look at your request. You can use the '
                    'console once they approve it.',
          style: t.bodyMedium,
        ),
        if (session?.email case final email?) ...[
          const SizedBox(height: LwSpacing.xs),
          Text('Signed in as $email', style: t.bodySmall),
        ],
        const SizedBox(height: LwSpacing.md),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('request-name'),
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
              ),
              const SizedBox(height: LwSpacing.xs),
              TextFormField(
                key: const Key('request-reason'),
                controller: _reason,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Why do you need access?',
                  hintText: 'For example: I write the sleep lessons.',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Say briefly why you need access.'
                    : null,
              ),
            ],
          ),
        ),
        if (_error case final e?) ...[
          const SizedBox(height: LwSpacing.xs),
          Text(
            e,
            key: const Key('request-error'),
            style: t.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: LwSpacing.md),
        FilledButton(
          key: const Key('request-send'),
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Sending…' : 'Send request'),
        ),
        const SizedBox(height: LwSpacing.xs),
        OutlinedButton(
          key: const Key('sign-out'),
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// Waiting for a Superadmin (D-112). Opens the console by itself once
/// approved (the access state is live).
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    return _StepPage(
      key: const Key('pending'),
      title: 'Waiting for approval',
      children: [
        Text(
          'Your request was sent. A Superadmin will approve or decline it. '
          'This page opens the console as soon as you are approved.',
          style: t.bodyMedium,
        ),
        if (session?.email case final email?) ...[
          const SizedBox(height: LwSpacing.xs),
          Text('Signed in as $email', style: t.bodySmall),
        ],
        const SizedBox(height: LwSpacing.lg),
        OutlinedButton(
          key: const Key('sign-out'),
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
