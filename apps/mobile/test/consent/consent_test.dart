import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/consent/presentation/consents_screen.dart';
import 'package:livewell/l10n/app_localizations.dart';

/// In-memory append-only store, standing in for Firestore.
class FakeConsentRepository implements ConsentRepository {
  final records = <ConsentRecord>[];

  /// The `grantedAt` passed for each type's latest record.
  final grantedAt = <ConsentType, DateTime?>{};
  final _changes = StreamController<List<ConsentRecord>>.broadcast();
  var _clock = DateTime.utc(2026, 10, 13);
  bool failNext = false;

  @override
  Stream<List<ConsentRecord>> watchRecords() async* {
    yield List.of(records);
    yield* _changes.stream;
  }

  @override
  Future<void> record(
    ConsentType type, {
    required bool granted,
    DateTime? grantedAt,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('offline and rejected');
    }
    _clock = _clock.add(const Duration(minutes: 1));
    this.grantedAt[type] = grantedAt;
    records.add(
      ConsentRecord(
        type: type,
        docVersion: ConsentTexts.versionOf(type),
        granted: granted,
        appVersion: '1.0.0',
        createdAt: _clock,
      ),
    );
    _changes.add(List.of(records));
  }
}

ConsentRecord rec(ConsentType t, bool granted, DateTime? at) => ConsentRecord(
  type: t,
  docVersion: 'v',
  granted: granted,
  appVersion: '1',
  createdAt: at,
);

Future<FakeConsentRepository> pumpScreen(WidgetTester tester) async {
  final repo = FakeConsentRepository();
  // Tall enough that the lazy list builds every row.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [consentRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: LwTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConsentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('currentConsents (append-only, latest wins)', () {
    final t1 = DateTime.utc(2026, 10, 1);
    final t2 = DateTime.utc(2026, 10, 2);

    test('a later revocation overrides an earlier grant', () {
      final current = currentConsents([
        rec(ConsentType.marketing, true, t1),
        rec(ConsentType.marketing, false, t2),
      ]);
      expect(isGranted(current, ConsentType.marketing), isFalse);
    });

    test('order of arrival does not matter, the timestamp does', () {
      final current = currentConsents([
        rec(ConsentType.analytics, false, t2),
        rec(ConsentType.analytics, true, t1),
      ]);
      expect(isGranted(current, ConsentType.analytics), isFalse);
    });

    test('a pending (offline, no server time yet) record is the newest', () {
      final current = currentConsents([
        rec(ConsentType.camera, false, null),
        rec(ConsentType.camera, true, t2),
      ]);
      expect(isGranted(current, ConsentType.camera), isFalse);
    });

    test('no record means not granted', () {
      expect(isGranted(currentConsents([]), ConsentType.microphone), isFalse);
    });

    test('every type has a stable, unique key and a draft version', () {
      final keys = ConsentType.values.map((t) => t.key).toSet();
      expect(keys.length, ConsentType.values.length);
      expect(ConsentType.granular, hasLength(8)); // FR-ONB-03 list
      for (final t in ConsentType.values) {
        expect(ConsentType.fromKey(t.key), t);
        expect(ConsentTexts.versionOf(t), startsWith('${t.key}-'));
      }
    });
  });

  testWidgets('every granular consent can be granted and then revoked', (
    tester,
  ) async {
    final repo = await pumpScreen(tester);
    expect(find.byType(SwitchListTile), findsNWidgets(8));

    for (var i = 0; i < 8; i++) {
      final tile = find.byType(SwitchListTile).at(i);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    }

    // 16 records: nothing was overwritten, each change was appended.
    expect(repo.records, hasLength(16));
    for (final type in ConsentType.granular) {
      final forType = repo.records.where((r) => r.type == type).toList();
      expect(forType.map((r) => r.granted), [true, false]);
      expect(forType.first.docVersion, ConsentTexts.versionOf(type));
    }
  });

  testWidgets('legal documents are read-only and show the accepted version', (
    tester,
  ) async {
    final repo = await pumpScreen(tester);
    await repo.record(ConsentType.terms, granted: true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Terms of Service'), 100);
    final version = ConsentTexts.versionOf(ConsentType.terms);
    expect(find.text('Accepted · version $version'), findsOneWidget);
    expect(find.text('Not accepted yet'), findsNWidgets(3));
  });

  testWidgets('a failed save tells the user and keeps the old state', (
    tester,
  ) async {
    final repo = await pumpScreen(tester);
    repo.failNext = true;
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(
      find.text("We couldn't save that change. Please try again."),
      findsOneWidget,
    );
    final first = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(first).value, isFalse);
    expect(repo.records, isEmpty);
  });

  testWidgets('shows that the wording is still a draft', (tester) async {
    await pumpScreen(tester);
    expect(
      find.text('Draft wording. The final text comes after legal review.'),
      findsOneWidget,
    );
  });
}
