import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/components/lw_components.dart';
import 'package:livewell/core/design/theme.dart';

/// Golden images of the core components in light and dark (T-FND-04).
/// Regenerate after an intended visual change:
///   flutter test --update-goldens test/design/components_golden_test.dart
/// Goldens are rendered on Windows; CI must use the same OS or keep its own set.
void main() {
  Widget gallery() => const SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LwSectionHeader('Today'),
        LwCard(
          eyebrow: 'From the Live Well Portal',
          title: 'Steadier blood sugar',
          body: 'Dr Murthy Gokula · 8 sections',
          tag: LwTag('Paid course'),
        ),
        SizedBox(height: 12),
        LwCard(title: 'Box breathing', body: '3 minutes · audio'),
        LwEmptyState(
          icon: Icons.wb_sunny_outlined,
          title: 'Your day starts here',
          body: 'Your morning briefing and one next step will show up here.',
        ),
      ],
    ),
  );

  for (final (name, theme) in [
    ('light', LwTheme.light()),
    ('dark', LwTheme.dark()),
  ]) {
    testWidgets('core components ($name)', (tester) async {
      tester.view.physicalSize = const Size(400, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(body: gallery()),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/components_$name.png'),
      );
    });
  }
}
