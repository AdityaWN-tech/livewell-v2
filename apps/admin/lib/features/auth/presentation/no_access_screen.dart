import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/design/admin_layout.dart';
import '../../../core/design/tokens.dart';

/// Signed in, but not a staff member, or a staff member without two-step
/// sign-in (MFA, spec 16.2; D-92). Nothing of the catalog is loaded here.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final t = Theme.of(context).textTheme;
    final staff = session?.isStaff ?? false;
    final (title, body) = staff
        ? (
            'Two-step sign-in needed',
            'Staff accounts need two-step sign-in before the console opens. '
                'Ask the owner to turn it on for your account, then sign in '
                'again.',
          )
        : (
            'No access',
            'This account has no staff role. If you should have one, ask the '
                'owner, then sign in again.',
          );
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LwSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdminLayout.narrowPageWidth,
            ),
            child: Column(
              key: Key(staff ? 'no-access-mfa' : 'no-access-role'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: t.headlineSmall),
                ),
                const SizedBox(height: LwSpacing.sm),
                Text(body, style: t.bodyMedium),
                if (session?.email case final email?) ...[
                  const SizedBox(height: LwSpacing.sm),
                  Text('Signed in as $email', style: t.bodySmall),
                ],
                const SizedBox(height: LwSpacing.lg),
                FilledButton(
                  key: const Key('no-access-retry'),
                  onPressed: () => ref.read(authRepositoryProvider).refresh(),
                  child: const Text('Check again'),
                ),
                const SizedBox(height: LwSpacing.xs),
                OutlinedButton(
                  key: const Key('sign-out'),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
