import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/flavor.dart';
import '../../checkin/data/checkin_repository.dart';
import '../../checkin/domain/checkin.dart';
import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';

/// Dev-flavor-only "Preview the app": skips sign-in so the shell, Settings and
/// consents can be explored on a device before sign-in (T-ONB-01) exists.
/// Nothing is saved: consents go to [InMemoryConsentRepository].
/// The button that turns it on is shown only in the dev flavor, and
/// [enable] refuses to work in any other flavor (AGENTS.md, Developer-only UI).
class PreviewMode extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() {
    if (ref.read(flavorProvider) != Flavor.dev) return;
    state = true;
  }
}

final previewModeProvider = NotifierProvider<PreviewMode, bool>(
  PreviewMode.new,
);

/// Keeps consent records in memory only, for preview mode.
class InMemoryConsentRepository implements ConsentRepository {
  final _records = <ConsentRecord>[];
  final _changes = StreamController<List<ConsentRecord>>.broadcast();

  @override
  Stream<List<ConsentRecord>> watchRecords() async* {
    yield List.of(_records);
    yield* _changes.stream;
  }

  @override
  Future<void> record(
    ConsentType type, {
    required bool granted,
    DateTime? grantedAt,
  }) async {
    _records.add(
      ConsentRecord(
        type: type,
        docVersion: ConsentTexts.versionOf(type),
        granted: granted,
        appVersion: 'preview',
        createdAt: DateTime.now(),
      ),
    );
    _changes.add(List.of(_records));
  }
}

/// Keeps check-ins in memory only, for preview mode (nothing is saved).
class InMemoryCheckInRepository implements CheckInRepository {
  final _days = <String, CheckIn>{};
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<CheckIn?> watchDay(String date) async* {
    yield _days[date];
    yield* _changes.stream.where((d) => d == date).map((d) => _days[d]);
  }

  @override
  Future<void> save(CheckIn checkIn) async {
    _days[checkIn.date] = checkIn;
    _changes.add(checkIn.date);
  }

  @override
  Future<List<CheckIn>> range(String from, String to) async =>
      checkInsBetween(_days.values, from, to);
}

/// One in-memory store per app run, so preview check-ins survive tab changes.
final previewCheckInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => InMemoryCheckInRepository(),
);
