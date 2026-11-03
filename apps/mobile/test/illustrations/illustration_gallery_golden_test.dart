@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/illustration/illustration.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/avatar/data/avatar_repository.dart';
import 'package:livewell/features/dev/presentation/illustration_gallery.dart';
import 'package:livewell/l10n/app_localizations.dart';

import '../support/fakes.dart';
import 'illustration_test.dart' show catalog;

/// The dev Illustrations screen (T-UI-02b): every placeholder and the coach
/// in all 6 expressions, light and dark, text at 100%, 130% and 200%, at
/// iPhone SE width (375 dp). Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  setUp(() => IllustrationCatalog.debugValue = catalog);
  tearDown(() => IllustrationCatalog.debugValue = null);

  for (final dark in [false, true]) {
    for (final (size, scale, height) in [
      ('normal', 1.0, 2300.0),
      ('medium', 1.3, 2700.0),
      ('large', 2.0, 3500.0),
    ]) {
      final name = 'illustrations_${dark ? 'dark' : 'light'}_$size';
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = Size(375, height)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              avatarRepositoryProvider.overrideWithValue(
                FakeAvatarRepository(),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? LwTheme.dark() : LwTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const IllustrationGallery(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(IllustrationGallery),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
