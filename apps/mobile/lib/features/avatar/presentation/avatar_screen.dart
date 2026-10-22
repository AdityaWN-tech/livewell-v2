import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../account/application/account_setup.dart' show voicePath;
import '../../account/data/profile_repository.dart';
import '../../auth/data/firebase_auth_service.dart';
import '../../studio/presentation/studio_screen.dart';

/// "Meet your coach" (T-ONB-03b), the first step after sign-up: the Avatar
/// Studio (T-AVT-08b) without the Voice tab. "Use this coach" waits for the
/// person's pick (never a guessed look, D-28); "Skip" takes the default.
class AvatarScreen extends ConsumerWidget {
  const AvatarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StudioScreen(
    onboarding: true,
    onSaved: () async {
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(profileRepositoryProvider).setStep(uid, ProfileStep.voice);
      if (context.mounted) context.go(voicePath);
    },
  );
}
