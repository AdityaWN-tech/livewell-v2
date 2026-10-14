import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/flavor.dart';

void main() {
  test('app code never uses FirebaseFirestore.instance (D-16)', () {
    final pattern = RegExp(r'FirebaseFirestore\.instance(?!For)');
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final code = f
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      if (pattern.hasMatch(code)) offenders.add(f.path);
    }
    expect(offenders, isEmpty, reason: 'use firestoreProvider instead');
  });

  test('dev points at the (default) database', () {
    expect(Flavor.dev.firestoreDatabaseId, '(default)');
  });
}
