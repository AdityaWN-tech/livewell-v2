import 'package:flutter/material.dart';

import '../../../core/design/components/lw_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';

/// Learn tab. Will hold: Book lessons by driver, audio and breathwork, avatar-narrated lessons, portal courses (spec 14.2).
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LwScreen(
      actions: const [SettingsAction()],
      title: l10n.tabLearn,
      children: [
        LwEmptyState(
          icon: Icons.menu_book_outlined,
          title: l10n.learnEmptyTitle,
          body: l10n.learnEmptyBody,
        ),
      ],
    );
  }
}
