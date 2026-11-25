import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import '../design/admin_layout.dart';
import '../design/tokens.dart';

/// Page frame: title, who is signed in (email and roles) and Sign out.
/// Content is centred and kept to a readable width on wide screens.
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final t = Theme.of(context).textTheme;
    final p = LwPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Semantics(header: true, child: Text(title)),
        actions: [
          ...actions,
          if (session != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LwSpacing.xs),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AdminLayout.appBarIdentity,
                  ),
                  child: Text(
                    [
                      ?session.email,
                      session.roles.map((r) => r.label).join(', '),
                    ].join(' · '),
                    style: t.bodySmall?.copyWith(color: p.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            TextButton(
              key: const Key('sign-out'),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ],
          const SizedBox(width: LwSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdminLayout.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(LwSpacing.lg),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
