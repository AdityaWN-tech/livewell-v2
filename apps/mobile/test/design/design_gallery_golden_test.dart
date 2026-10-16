@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/dev/presentation/design_gallery.dart';

/// Golden images of the dev Design tokens screen (T-UI-01a, T-UI-02a): light and dark,
/// text at 100%, 130% and 200%. Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  for (final (name, theme) in [
    ('light', LwTheme.light()),
    ('dark', LwTheme.dark()),
  ]) {
    for (final (size, scale, height) in [
      ('normal', 1.0, 2400.0),
      ('medium', 1.3, 3500.0),
      ('large', 2.0, 5200.0),
    ]) {
      testWidgets('design tokens screen ($name, $size text)', (tester) async {
        tester.view.physicalSize = Size(400, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const DesignGallery(),
          ),
        );
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
          // Let the decoded logo reach the Image widget.
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(DesignGallery),
          matchesGoldenFile('goldens/design_tokens_${name}_$size.png'),
        );
      });
    }
  }
}
