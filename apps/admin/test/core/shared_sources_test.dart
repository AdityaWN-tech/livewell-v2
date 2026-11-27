import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell_admin/core/auth/staff.dart';
import 'package:livewell_admin/features/portal_offers/domain/offer_validation.dart';
import 'package:livewell_admin/features/portal_offers/domain/portal_offer.dart';

// The console copies a few things it can't import (D-92). These tests fail
// when a copy drifts from its source.
void main() {
  test('design tokens are exact copies of the app', () {
    for (final f in ['tokens.dart', 'typography.dart', 'theme.dart']) {
      expect(
        File('lib/core/design/$f').readAsStringSync(),
        File('../mobile/lib/core/design/$f').readAsStringSync(),
        reason: 'Copy apps/mobile/lib/core/design/$f to apps/admin.',
      );
    }
  });

  test('preview words match the app card', () {
    final arb = File('../mobile/lib/l10n/app_en.arb').readAsStringSync();
    for (final w in [
      '"learnPortalEyebrow": "From the Live Well Portal"',
      '"learnPaidCourse": "Paid course"',
      '"learnFreeLesson": "Free lesson"',
      '"learnViewCourse": "View course"',
      '"learnNotNow": "Not now"',
    ]) {
      expect(arb, contains(w));
    }
  });

  test('only staff access talks to Firestore directly (D-112)', () {
    // The catalog goes through the Core API (role, MFA, audit). Staff
    // access on the free plan is the one exception: its Firestore rules
    // are the guard (firebase/test/rules.test.ts). Nothing else may.
    const allowed = {
      'lib/features/staff/data/staff_access_repository.dart',
      'lib/features/content/data/content_repository.dart',
      'lib/main.dart',
    };
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) continue;
      final src = f.readAsStringSync();
      expect(src, isNot(contains('cloud_firestore')), reason: path);
      expect(src, isNot(contains('FirebaseFirestore')), reason: path);
    }
  });

  group('matches the Core API (services/core-api)', () {
    final model = File(
      '../../services/core-api/src/portal/portal-offer-model.ts',
    ).readAsStringSync();
    final staffTs = File('../../services/core-api/src/admin/staff.ts')
        .readAsStringSync();

    List<String> tsList(String src, String name) {
      final m = RegExp('export const $name = \\[([^\\]]*)\\]').firstMatch(src)!;
      return RegExp("'([^']+)'")
          .allMatches(m.group(1)!)
          .map((x) => x.group(1)!)
          .toList();
    }

    test('portal hosts', () {
      expect(tsList(model, 'PORTAL_HOSTS'), portalHosts);
    });
    test('offer types, statuses and actions', () {
      expect(tsList(model, 'OFFER_TYPES'), OfferType.values.map((t) => t.id));
      expect(
        tsList(model, 'REVIEW_STATUSES'),
        ReviewStatus.values.map((s) => s.id),
      );
      expect(tsList(model, 'TRANSITIONS'), OfferAction.values.map((a) => a.id));
    });
    test('staff roles', () {
      expect(
        tsList(staffTs, 'STAFF_ROLES'),
        StaffRole.values.map((r) => r.claim),
      );
    });
  });
}
