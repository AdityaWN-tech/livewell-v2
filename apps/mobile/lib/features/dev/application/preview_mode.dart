import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../consent/data/consent_repository.dart';
import '../../consent/domain/consent.dart';

/// Dev-flavor-only "Preview the app": skips sign-in so the shell, Settings and
/// consents can be explored on a device before sign-in (T-ONB-01) exists.
/// Nothing is saved: consents go to [InMemoryConsentRepository].
/// The button that turns it on is shown only in the dev flavor.
class PreviewMode extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;
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
  Future<void> record(ConsentType type, {required bool granted}) async {
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
