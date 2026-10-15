import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../account/application/account_setup.dart';
import '../data/firebase_auth_service.dart';
import '../domain/auth.dart';

/// Plain-language message for a sign-in failure. Null = say nothing (the
/// user cancelled on purpose).
String? authErrorText(AppLocalizations l, AuthFailure f) => switch (f) {
  AuthFailure.invalidEmail => l.authErrorInvalidEmail,
  AuthFailure.wrongCredentials => l.authErrorWrongCredentials,
  AuthFailure.emailInUse => l.authErrorEmailInUse,
  AuthFailure.weakPassword => l.authErrorWeakPassword,
  AuthFailure.invalidPhone => l.authErrorInvalidPhone,
  AuthFailure.wrongCode => l.authErrorWrongCode,
  AuthFailure.codeExpired => l.authErrorCodeExpired,
  AuthFailure.tooManyRequests => l.authErrorTooMany,
  AuthFailure.network => l.authErrorNetwork,
  AuthFailure.methodDisabled => l.authErrorMethodDisabled,
  AuthFailure.accountExists => l.authErrorAccountExists,
  AuthFailure.cancelled => null,
  AuthFailure.unknown => l.authErrorUnknown,
};

void showAuthMessage(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs a sign-in [attempt], then account setup, then opens the next screen.
/// Shows a friendly message on failure. Returns true if it moved on.
Future<bool> runSignIn(
  BuildContext context,
  WidgetRef ref,
  Future<AuthUser> Function() attempt,
) async {
  final l = AppLocalizations.of(context);
  final auth = ref.read(authServiceProvider);
  final AuthUser user;
  try {
    user = await attempt();
  } on AuthException catch (e) {
    if (context.mounted) showAuthMessage(context, authErrorText(l, e.failure));
    return false;
  }
  if (context.mounted) await _offerPendingLink(context, auth, user);
  try {
    final next = await ref.read(signInCompletionProvider).complete(user);
    if (context.mounted) context.go(next);
    return true;
  } catch (_) {
    if (context.mounted) showAuthMessage(context, l.accountSetupError);
    return false;
  }
}

/// After a Google/Apple attempt found this person's existing account, and
/// they then signed in the original way: offer to add Google/Apple to it.
/// Only into the account with the same email; nothing is linked silently.
Future<void> _offerPendingLink(
  BuildContext context,
  AuthService auth,
  AuthUser user,
) async {
  final pending = auth.pendingLink;
  if (pending == null) return;
  if (!pending.matches(user)) {
    auth.clearPendingLink();
    return;
  }
  final l = AppLocalizations.of(context);
  final name = pending.provider.brandName;
  final add = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.authLinkTitle(name)),
      content: Text(l.authLinkBody(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.authLinkNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.authLinkAdd(name)),
        ),
      ],
    ),
  );
  if (add != true) {
    auth.clearPendingLink();
    return;
  }
  try {
    await auth.linkPending();
    if (context.mounted) showAuthMessage(context, l.authLinkDone(name));
  } on AuthException catch (e) {
    if (context.mounted) showAuthMessage(context, authErrorText(l, e.failure));
  }
}
