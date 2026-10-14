import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/onboarding/domain/onboarding_progress.dart';
import 'package:livewell/features/onboarding/presentation/legal_screen.dart';

/// The app's bundled legal texts must be exact copies of content/legal (the
/// versioned source of truth, spec 17.2), one per legal document version.
void main() {
  for (final type in legalDocuments) {
    test('${type.key}: bundled text exists and matches content/legal', () {
      final bundled = File(legalAssetPath(type));
      final source = File(
        '../../content/legal/${ConsentTexts.versionOf(type)}.md',
      );
      expect(bundled.existsSync(), isTrue, reason: bundled.path);
      expect(source.existsSync(), isTrue, reason: source.path);
      expect(bundled.readAsStringSync(), source.readAsStringSync());
    });
  }

  test('draft texts say they are drafts until counsel signs off', () {
    for (final type in legalDocuments) {
      final text = File(legalAssetPath(type)).readAsStringSync();
      if (ConsentTexts.draftVersion.contains('draft')) {
        expect(text, contains('DRAFT for review'), reason: type.key);
      }
    }
  });
}
