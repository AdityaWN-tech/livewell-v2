import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/app.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/firebase/firebase_options.dart';

void main() {
  for (final flavor in Flavor.values) {
    testWidgets('${flavor.name} boots and shows its banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flavorProvider.overrideWithValue(flavor)],
          child: const LiveWellApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Live Well'), findsOneWidget);
      final banner = find.byWidgetPredicate(
        (w) => w is Banner && w.message == flavor.label,
      );
      expect(banner, flavor.label == null ? findsNothing : findsOneWidget);
    });
  }

  test('only dev has a Firebase project yet', () {
    expect(Flavor.dev.firebaseProjectId, 'my-livewell');
    expect(Flavor.staging.firebaseProjectId, isNull);
    expect(Flavor.prod.firebaseProjectId, isNull);
  });

  test('Firebase options exist for dev only', () {
    expect(firebaseOptionsFor(Flavor.dev)?.projectId, 'my-livewell');
    expect(firebaseOptionsFor(Flavor.staging), isNull);
    expect(firebaseOptionsFor(Flavor.prod), isNull);
  });
}
