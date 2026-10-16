import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/application/home_data.dart';
import '../data/account_actions.dart';

/// The person's picture (or initial) at the top-right of every tab header,
/// opening Profile (T-ONB-03f, Option A: keeps the 5-tab bar).
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  static const path = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const Key('profile-button'),
      tooltip: l.profileOpen,
      onPressed: () => context.push(path),
      icon: ProfilePicture(radius: LwSize.iconMd * 0.75),
    );
  }
}

class ProfilePicture extends ConsumerWidget {
  const ProfilePicture({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LwPalette.of(context);
    final photo = ref.watch(profilePhotoProvider).value;
    final name = ref.watch(firstNameProvider);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: p.primaryTint,
        foregroundImage: photo == null ? null : FileImage(File(photo)),
        child: name == null || name.isEmpty
            ? Icon(Icons.person_outline, size: radius * 1.2, color: p.primary)
            : Text(
                name.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: p.onPrimaryTint, fontSize: radius * 0.9),
              ),
      ),
    );
  }
}
