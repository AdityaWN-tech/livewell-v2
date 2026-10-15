@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/avatar/avatar_art.dart';
import 'package:livewell/features/avatar/domain/avatar_config.dart';

/// The illustrated avatar across looks, tones, hair and coverings (T-ONB-03b).
/// Regenerate after an intended change:
///   flutter test --update-goldens --tags golden
void main() {
  testWidgets('avatar art sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = AvatarConfig.fallback;
    final configs = [
      AvatarConfig.forLook(AvatarLook.woman),
      AvatarConfig.forLook(AvatarLook.man),
      AvatarConfig.forLook(AvatarLook.neutral),
      for (var i = 0; i < AvatarPalettes.skinTones; i++)
        base.copyWith(skin: i, background: i % AvatarPalettes.backgrounds),
      for (final h in HairStyle.values)
        base.copyWith(
          hair: h,
          hairColour: h.index % AvatarPalettes.hairColours,
        ),
      for (final g in Glasses.values) base.copyWith(glasses: g, skin: 7),
      for (final hc in HeadCovering.values)
        base.copyWith(headCovering: hc, skin: 6, clothingColour: 3),
      for (final e in EyeShape.values) base.copyWith(eyes: e, skin: 2),
      for (final c in Clothing.values)
        base.copyWith(clothing: c, clothingColour: c.index + 3),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in configs) AvatarView(config: c, size: 72),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/avatar_art_sheet.png'),
    );
  });
}
