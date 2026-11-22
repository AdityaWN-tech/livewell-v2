import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/core/config/feature_flags.dart';
import 'package:livewell/core/config/flavor.dart';
import 'package:livewell/core/design/theme.dart';
import 'package:livewell/core/routing/router.dart';
import 'package:livewell/features/account/data/profile_repository.dart';
import 'package:livewell/features/auth/domain/auth.dart';
import 'package:livewell/features/consent/data/consent_repository.dart';
import 'package:livewell/features/consent/domain/consent.dart';
import 'package:livewell/features/memory/application/memory_enabled.dart';
import 'package:livewell/features/memory/data/memory_repository.dart';
import 'package:livewell/features/memory/domain/memory_fact.dart';
import 'package:livewell/features/memory/presentation/memory_screen.dart';
import 'package:livewell/features/profile/presentation/profile_screen.dart';
import 'package:livewell/l10n/app_localizations.dart';

import '../consent/consent_test.dart' show FakeConsentRepository;
import '../support/app_harness.dart';
import '../support/fakes.dart';

/// T-AGT-05b (D-101): "What my coach remembers". Keep needs the memory
/// consent (and the health-details opt-in for a sensitive fact); delete is
/// always allowed and final; hidden in staging/prod until the flag is on.

MemoryFact fact(
  String id,
  String text, {
  bool sensitive = false,
  MemoryStatus status = MemoryStatus.proposed,
}) => MemoryFact(
  id: id,
  fact: text,
  category: sensitive ? 'medication' : 'preference',
  sensitive: sensitive,
  status: status,
  createdAt: DateTime(2026, 11, 20),
);

Future<(InMemoryMemoryRepository, FakeConsentRepository)> pumpMemory(
  WidgetTester tester, {
  List<MemoryFact>? facts,
  Set<ConsentType> granted = const {ConsentType.memory},
}) async {
  final memory = InMemoryMemoryRepository(
    facts ??
        [
          fact('a', 'prefers walking after dinner'),
          fact('b', 'takes a morning tablet', sensitive: true),
          fact('c', 'knee gets sore on stairs', status: MemoryStatus.saved),
        ],
  );
  final consents = FakeConsentRepository();
  for (final t in granted) {
    await consents.record(t, granted: true);
  }
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        consentRepositoryProvider.overrideWithValue(consents),
        memoryRepositoryProvider.overrideWithValue(memory),
      ],
      child: MaterialApp(
        theme: LwTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (memory, consents);
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

Future<List<MemoryFact>> current(InMemoryMemoryRepository repo) =>
    repo.watch().first;

void main() {
  group('domain', () {
    test('fromMap keeps proposed and saved, drops deleted and malformed', () {
      final ok = MemoryFact.fromMap('x', {
        'fact': 'likes tea',
        'category': 'preference',
        'status': 'proposed',
      });
      expect(ok?.status, MemoryStatus.proposed);
      expect(ok?.sensitive, isFalse);
      for (final bad in [
        {'fact': '', 'category': 'preference', 'status': 'deleted'},
        {'fact': 'x', 'category': 'preference', 'status': 'deleted'},
        {'fact': '', 'category': 'preference', 'status': 'saved'},
        {'fact': 'x', 'status': 'saved'},
        {'fact': 'x', 'category': 'preference', 'status': 'weird'},
      ]) {
        expect(MemoryFact.fromMap('x', bad), isNull, reason: '$bad');
      }
      expect(MemoryFact.fromMap('x', null), isNull);
    });

    test('a sensitive category is sensitive even without the flag', () {
      final f = MemoryFact.fromMap('x', {
        'fact': 'sees a counsellor',
        'category': 'mental_health',
        'status': 'proposed',
      });
      expect(f?.sensitive, isTrue);
    });

    test('keepBlock', () {
      final plain = fact('a', 'x');
      final health = fact('b', 'y', sensitive: true);
      expect(
        keepBlock(plain, memoryOn: false, sensitiveOn: true),
        KeepBlock.memoryOff,
      );
      expect(
        keepBlock(health, memoryOn: true, sensitiveOn: false),
        KeepBlock.needsSensitiveOptIn,
      );
      expect(
        keepBlock(health, memoryOn: true, sensitiveOn: true),
        KeepBlock.none,
      );
      expect(
        keepBlock(plain, memoryOn: true, sensitiveOn: false),
        KeepBlock.none,
      );
    });

    test('memory consents are not in the general Privacy list', () {
      expect(ConsentType.granular, isNot(contains(ConsentType.memory)));
      expect(
        ConsentType.granular,
        isNot(contains(ConsentType.memorySensitive)),
      );
      expect(ConsentType.memory.key, 'memory');
      expect(ConsentType.memorySensitive.key, 'memory_sensitive');
    });
  });

  group('screen', () {
    testWidgets('lists suggestions and remembered facts', (tester) async {
      await pumpMemory(tester);
      expect(find.text('Suggestions to keep'), findsOneWidget);
      expect(find.text('Remembered'), findsOneWidget);
      expect(find.text('prefers walking after dinner'), findsOneWidget);
      expect(find.text('knee gets sore on stairs'), findsOneWidget);
      expect(find.text('Health detail'), findsOneWidget);
      // No Keep button on a fact that is already remembered.
      expect(find.byKey(const Key('memory-keep-c')), findsNothing);
    });

    testWidgets('keeping a plain fact moves it to Remembered', (tester) async {
      final (repo, _) = await pumpMemory(tester);
      expect(enabled(tester, 'memory-keep-a'), isTrue);
      await tester.tap(find.byKey(const Key('memory-keep-a')));
      await tester.pumpAndSettle();
      final a = (await current(repo)).firstWhere((f) => f.id == 'a');
      expect(a.status, MemoryStatus.saved);
      expect(find.byKey(const Key('memory-keep-a')), findsNothing);
    });

    testWidgets('a health detail needs the opt-in before it can be kept', (
      tester,
    ) async {
      final (repo, consents) = await pumpMemory(tester);
      expect(enabled(tester, 'memory-keep-b'), isFalse);
      expect(
        find.text('To keep this, turn on Include health details.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('memory-sensitive-consent')));
      await tester.pumpAndSettle();
      expect(consents.records.last.type, ConsentType.memorySensitive);
      expect(enabled(tester, 'memory-keep-b'), isTrue);
      await tester.tap(find.byKey(const Key('memory-keep-b')));
      await tester.pumpAndSettle();
      final b = (await current(repo)).firstWhere((f) => f.id == 'b');
      expect(b.status, MemoryStatus.saved);
    });

    testWidgets('memory off: nothing can be kept, everything can be deleted', (
      tester,
    ) async {
      final (repo, _) = await pumpMemory(tester, granted: const {});
      expect(find.byKey(const Key('memory-off-note')), findsOneWidget);
      expect(enabled(tester, 'memory-keep-a'), isFalse);
      // Health details can't be switched on while memory itself is off.
      final sensitive = tester.widget<SwitchListTile>(
        find.descendant(
          of: find.byKey(const Key('memory-sensitive-consent')),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(sensitive.onChanged, isNull);
      await tester.tap(find.byKey(const Key('memory-delete-a')));
      await tester.pumpAndSettle();
      expect((await current(repo)).map((f) => f.id), isNot(contains('a')));
      expect(find.text('prefers walking after dinner'), findsNothing);
    });

    testWidgets('health opt-in shows off while memory is off', (tester) async {
      await pumpMemory(tester, granted: const {ConsentType.memorySensitive});
      final sensitive = tester.widget<SwitchListTile>(
        find.descendant(
          of: find.byKey(const Key('memory-sensitive-consent')),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(sensitive.value, isFalse);
    });

    testWidgets('turning memory on records a consent', (tester) async {
      final (_, consents) = await pumpMemory(tester, granted: const {});
      await tester.tap(find.byKey(const Key('memory-consent')));
      await tester.pumpAndSettle();
      expect(consents.records.single.type, ConsentType.memory);
      expect(consents.records.single.granted, isTrue);
    });

    testWidgets('delete everything asks first, then deletes all', (
      tester,
    ) async {
      final (repo, _) = await pumpMemory(tester);
      await tester.tap(find.byKey(const Key('memory-delete-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await current(repo), hasLength(3));
      await tester.tap(find.byKey(const Key('memory-delete-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('memory-delete-all-confirm')));
      await tester.pumpAndSettle();
      expect(await current(repo), isEmpty);
      expect(find.text('Nothing remembered yet'), findsOneWidget);
    });

    testWidgets('empty list explains what will happen', (tester) async {
      await pumpMemory(tester, facts: const []);
      expect(find.text('Nothing remembered yet'), findsOneWidget);
      expect(find.byKey(const Key('memory-delete-all')), findsNothing);
    });

    testWidgets('screen readers hear a disabled Keep as disabled and can '
        'activate Keep and Delete', (tester) async {
      final handle = tester.ensureSemantics();
      final (repo, _) = await pumpMemory(tester);
      // b is a health detail without the opt-in: Keep is disabled.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Keep: takes a morning tablet'),
        ),
        matchesSemantics(
          label: 'Keep: takes a morning tablet',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      final keepA = tester.getSemantics(
        find.bySemanticsLabel('Keep: prefers walking after dinner'),
      );
      expect(
        keepA,
        matchesSemantics(
          label: 'Keep: prefers walking after dinner',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      // Activate through the semantics tree, as TalkBack does.
      tester.semantics.tap(
        find.semantics.byLabel('Keep: prefers walking after dinner'),
      );
      await tester.pumpAndSettle();
      expect(
        (await current(repo)).firstWhere((f) => f.id == 'a').status,
        MemoryStatus.saved,
      );
      tester.semantics.tap(
        find.semantics.byLabel('Delete: knee gets sore on stairs'),
      );
      await tester.pumpAndSettle();
      expect((await current(repo)).map((f) => f.id), isNot(contains('c')));
      handle.dispose();
    });

    testWidgets('Keep and Delete buttons name the fact for screen readers', (
      tester,
    ) async {
      await pumpMemory(tester);
      expect(
        find.bySemanticsLabel('Keep: prefers walking after dinner'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Delete: knee gets sore on stairs'),
        findsOneWidget,
      );
    });
  });

  group('where it shows (D-101)', () {
    Harness signedIn(
      Flavor flavor, {
      FeatureFlags flags = const FeatureFlags(),
    }) {
      final h = Harness(
        flavor: flavor,
        flags: flags,
        auth: FakeAuthService(signedIn: const AuthUser(uid: 'u1')),
      );
      h.profiles.existing['u1'] = ProfileStep.assessment;
      return h;
    }

    Future<void> openProfile(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-help-now')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
    }

    for (final flavor in [Flavor.staging, Flavor.prod]) {
      testWidgets('${flavor.name}: no Memory row in Profile', (tester) async {
        await signedIn(flavor).boot(tester);
        await openProfile(tester);
        expect(find.byKey(const Key('profile-memory')), findsNothing);
      });

      test('${flavor.name}: the memory route is not registered', () {
        final container = ProviderContainer(
          overrides: [flavorProvider.overrideWithValue(flavor)],
        );
        addTearDown(container.dispose);
        final match = container
            .read(routerProvider)
            .configuration
            .findMatch(Uri.parse(MemoryScreen.path));
        expect(match.matches, isEmpty);
      });

      test('${flavor.name}: the coachMemory flag turns it on', () {
        final container = ProviderContainer(
          overrides: [
            flavorProvider.overrideWithValue(flavor),
            featureFlagsProvider.overrideWithValue(
              const FeatureFlags(coachMemory: true),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(coachMemoryEnabledProvider), isTrue);
      });
    }

    testWidgets('dev: Profile has the Memory row', (tester) async {
      await signedIn(Flavor.dev).boot(tester);
      await openProfile(tester);
      expect(find.byKey(const Key('profile-memory')), findsOneWidget);
    });

    test('dev: the memory route is registered', () {
      final container = ProviderContainer(
        overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
      );
      addTearDown(container.dispose);
      final match = container
          .read(routerProvider)
          .configuration
          .findMatch(Uri.parse(MemoryScreen.path));
      expect(match.matches, isNotEmpty);
    });
  });
}
