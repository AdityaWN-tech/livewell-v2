import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/profile/data/data_export.dart';

import '../support/app_harness.dart';
import 'profile_test.dart' show openProfile, signedIn, tapKey;

/// "Download my data" (FR-SET-02, T-CMP-03, D-82).
void main() {
  /// The sheet shows a spinner while preparing, so never pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<Harness> openSheet(WidgetTester tester, {DataExportJob? job}) async {
    final h = signedIn();
    h.exports.latest = job;
    await h.boot(tester);
    await openProfile(tester);
    await tapKey(tester, 'profile-export');
    await settle(tester);
    expect(find.byKey(const Key('data-export-sheet')), findsOneWidget);
    return h;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('prepare, wait, then download through a short-lived link', (
    tester,
  ) async {
    final h = await openSheet(tester);
    expect(find.text('A copy of your data'), findsOneWidget);
    await tap(tester, 'data-export-start');
    expect(h.exports.requests, 1);
    expect(find.byKey(const Key('data-export-preparing')), findsOneWidget);
    expect(find.byKey(const Key('data-export-download')), findsNothing);

    h.exports.emit(
      DataExportJob(
        id: 'job1',
        status: DataExportStatus.ready,
        expiresAt: DateTime(2026, 10, 21, 9),
      ),
    );
    await settle(tester);
    expect(find.textContaining('until Wed, Oct 21.'), findsOneWidget);
    await tap(tester, 'data-export-download');
    expect(h.exports.links, ['job1']);
    expect(h.exports.opened.single.path, '/exports/job1.zip');
    // Nothing about the export goes to analytics.
    expect(h.analytics.events, isEmpty);
  });

  testWidgets('a failed export offers a retry', (tester) async {
    final h = await openSheet(
      tester,
      job: const DataExportJob(id: 'j0', status: DataExportStatus.failed),
    );
    expect(find.textContaining('couldn’t prepare'), findsOneWidget);
    await tap(tester, 'data-export-retry');
    expect(h.exports.requests, 1);
    expect(find.byKey(const Key('data-export-preparing')), findsOneWidget);
  });

  testWidgets('an expired export can be asked for again', (tester) async {
    await openSheet(
      tester,
      job: const DataExportJob(id: 'j0', status: DataExportStatus.expired),
    );
    expect(find.byKey(const Key('data-export-start')), findsOneWidget);
    expect(find.byKey(const Key('data-export-download')), findsNothing);
  });

  testWidgets('once a day: says when to try again', (tester) async {
    final h = signedIn();
    h.exports.requestError = DataExportLimited(DateTime(2026, 10, 15, 9));
    await h.boot(tester);
    await openProfile(tester);
    await tapKey(tester, 'profile-export');
    await settle(tester);
    await tap(tester, 'data-export-start');
    expect(
      find.textContaining(
        'You can ask for a new copy once a day. '
        'Please try again after Thu, Oct 15, 9:00',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a server that is not reachable gets a kind message', (
    tester,
  ) async {
    final h = signedIn();
    h.exports.requestError = Exception('not deployed');
    await h.boot(tester);
    await openProfile(tester);
    await tapKey(tester, 'profile-export');
    await settle(tester);
    await tap(tester, 'data-export-start');
    expect(find.byKey(const Key('data-export-message')), findsOneWidget);
    expect(h.exports.requests, 0);
  });

  testWidgets('a link that fails says so', (tester) async {
    final h = await openSheet(
      tester,
      job: DataExportJob(
        id: 'j1',
        status: DataExportStatus.ready,
        expiresAt: DateTime(2026, 10, 21),
      ),
    );
    h.exports.linkError = Exception('offline');
    await tap(tester, 'data-export-download');
    expect(
      find.text('We couldn’t open the download. Please try again.'),
      findsOneWidget,
    );
    expect(h.exports.opened, isEmpty);
  });

  group('DataExportJob.fromMap (same rules as the server)', () {
    final now = DateTime(2026, 11, 16, 12);
    Timestamp ts(DateTime d) => Timestamp.fromDate(d);

    test('preparing for an hour counts as failed', () {
      DataExportStatus at(Duration ago) => DataExportJob.fromMap('j', {
        'status': 'preparing',
        'created_at': ts(now.subtract(ago)),
      }, now).status;
      expect(at(const Duration(minutes: 5)), DataExportStatus.preparing);
      expect(at(const Duration(minutes: 60)), DataExportStatus.failed);
    });

    test('ready until expires_at, then expired', () {
      DataExportStatus at(DateTime expires) => DataExportJob.fromMap('j', {
        'status': 'ready',
        'created_at': ts(now.subtract(const Duration(days: 1))),
        'expires_at': ts(expires),
      }, now).status;
      expect(at(now.add(const Duration(days: 6))), DataExportStatus.ready);
      expect(at(now), DataExportStatus.expired);
    });

    test('anything unknown is failed (retry), never ready', () {
      expect(
        DataExportJob.fromMap('j', {'status': 'weird'}, now).status,
        DataExportStatus.failed,
      );
    });
  });
}
