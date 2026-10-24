import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/routine.dart';
import 'package:livewell/features/routine/domain/routine_catalog.dart';

/// T-GOL-03a: the approved activity catalog and the coach's routine lines.

final contentFile = File('../../content/routine/catalog.json');
RoutineCatalog catalog() =>
    RoutineCatalog.parse(contentFile.readAsStringSync());

const custom = RoutineItem(
  itemId: 'c1',
  routineId: 'r1',
  label: 'Call mom about the doctor',
  icon: 'heart',
  time: '18:00',
  durationMin: 10,
);

/// The rules file's list in [function] (firebase/firestore.rules).
Set<String> rulesList(String function) {
  final rules = File('../../firebase/firestore.rules').readAsStringSync();
  final body = RegExp(
    'function $function'
    r'\(\) \{\s*return \[([^\]]*)\];',
  ).firstMatch(rules)!.group(1)!;
  return {for (final m in RegExp("'([a-z_]+)'").allMatches(body)) m.group(1)!};
}

void main() {
  group('the catalog file (content/routine)', () {
    test('the app copy matches content/routine/catalog.json', () {
      expect(
        File('assets/routine/catalog.json').readAsStringSync(),
        contentFile.readAsStringSync(),
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/routine/'),
      );
    });

    test('the activities the task lists, pending clinical review', () {
      final c = catalog();
      expect(c.approved, isFalse);
      expect(c.activities.map((a) => a.id), [
        'wake_up',
        'drink_water',
        'morning_stretch',
        'morning_walk',
        'breathing_break',
        'healthy_breakfast',
        'work_break',
        'walk_after_meal',
        'family_time',
        'read',
        'quiet_time',
        'screen_off',
        'sleep_wind_down',
        'bedtime',
      ]);
      for (final a in c.activities) {
        expect(a.lines.length, greaterThanOrEqualTo(2), reason: a.id);
        expect(
          a.lines.map((l) => l.id).toSet().length,
          a.lines.length,
          reason: '${a.id}: line ids are unique',
        );
        // One line works without the first name.
        expect(
          a.lines.any((l) => !l.placeholders.contains('first_name')),
          isTrue,
          reason: a.id,
        );
        expect(a.defaultDurationMin, inInclusiveRange(1, 30), reason: a.id);
      }
      expect(c.customLines, isNotEmpty);
    });

    test('movement items are the walking and stretching ones', () {
      expect(
        {
          for (final a in catalog().activities)
            if (a.movement) a.id,
        },
        {'morning_stretch', 'morning_walk', 'walk_after_meal'},
      );
    });

    test(
      'nothing v2 does not allow: fasting, calories, weight, medication',
      () {
        final banned = RegExp(
          r'\bfast(ing)?\b|calori|weight|diet|medic|pill|dose|supplement|vitamin|skip (a )?meal|burn',
          caseSensitive: false,
        );
        final c = catalog();
        final texts = [
          for (final a in c.activities) ...[
            a.id,
            a.label,
            a.spokenName,
            for (final l in a.lines) l.text,
          ],
          for (final l in c.customLines) l.text,
        ];
        for (final t in texts) {
          expect(banned.hasMatch(t), isFalse, reason: t);
        }
      },
    );

    test('lines are invitations at a plain reading level', () {
      final orders = RegExp(
        r'\byou (must|should|need to)\b|\bdon.t forget\b|\bfailed\b',
        caseSensitive: false,
      );
      final c = catalog();
      for (final l in [
        for (final a in c.activities) ...a.lines,
        ...c.customLines,
      ]) {
        expect(orders.hasMatch(l.text), isFalse, reason: l.text);
        expect(l.text.length, lessThanOrEqualTo(140), reason: l.text);
      }
    });

    test('unknown placeholders and icons are refused', () {
      String withLine(String text) => contentFile
          .readAsStringSync()
          .replaceFirst('Time for a glass of water.', text);
      expect(
        () => RoutineCatalog.parse(withLine('Time for {step_title}.')),
        throwsFormatException,
      );
      expect(
        () => RoutineCatalog.parse(
          contentFile.readAsStringSync().replaceFirst(
            '"icon": "water"',
            '"icon": "pill"',
          ),
        ),
        throwsFormatException,
      );
    });

    test('REVIEW.md lists every line for clinical review', () {
      final review = File('../../content/routine/REVIEW.md').readAsStringSync();
      final c = catalog();
      for (final a in c.activities) {
        for (final l in a.lines) {
          expect(review, contains('| `${a.id}.${l.id}` | ${l.text} |'));
        }
      }
      for (final l in c.customLines) {
        expect(review, contains('| `custom.${l.id}` | ${l.text} |'));
      }
    });

    test('the security rules allow exactly these activities and icons', () {
      expect(rulesList('routineCatalogIds'), {
        for (final a in catalog().activities) a.id,
      });
      expect(rulesList('routineIcons'), routineIcons);
    });
  });

  group('what the coach says (closed-script rule, FR-VOC-05)', () {
    test('a catalog item gets its own line with the name and time', () {
      final c = catalog();
      final item = c.newItem(
        c.byId('morning_stretch')!,
        itemId: 'i1',
        routineId: 'r1',
        activityLimited: false,
        time: '09:30',
      );
      final said = c.spokenLine(
        item,
        firstName: 'Priya',
        time: spokenTime(item.time),
        approvedOnly: false,
      );
      expect(
        said,
        "Hi Priya! It's 9:30, time for a little stretch. "
        'Go slowly and only as far as feels good.',
      );
    });

    test('without a first name, a line that does not need one', () {
      final c = catalog();
      final item = c.newItem(
        c.byId('drink_water')!,
        itemId: 'i1',
        routineId: 'r1',
        activityLimited: false,
      );
      for (var pick = 0; pick < 4; pick++) {
        final said = c.spokenLine(
          item,
          time: '7:15',
          approvedOnly: false,
          pick: pick,
        )!;
        expect(said, isNot(contains('{')));
        expect(said, contains('7:15'));
      }
    });

    test('a custom label is never part of what the coach says', () {
      final c = catalog();
      for (var pick = 0; pick < 4; pick++) {
        for (final name in [null, 'Priya']) {
          final said = c.spokenLine(
            custom,
            firstName: name,
            time: '6:00',
            approvedOnly: false,
            pick: pick,
          )!;
          expect(said, isNot(contains('Call mom')));
          expect(said, contains('next routine step'));
        }
      }
    });

    test('a custom item that copies a catalog label is still not spoken', () {
      final c = catalog();
      final said = c.spokenLine(
        custom.copyWith(label: 'Drink water then something else'),
        time: '6:00',
        approvedOnly: false,
      )!;
      expect(said, isNot(contains('something else')));
    });

    test('outside dev, nothing is said until the catalog is approved', () {
      final c = catalog();
      final item = c.newItem(
        c.byId('bedtime')!,
        itemId: 'i1',
        routineId: 'r1',
        activityLimited: false,
      );
      expect(c.spokenLine(item, time: '10:30', approvedOnly: true), isNull);
      expect(c.spokenLine(custom, time: '6:00', approvedOnly: true), isNull);
      final approved = RoutineCatalog.parse(
        contentFile.readAsStringSync().replaceFirst(
          '"review_status": "pending"',
          '"review_status": "approved"',
        ),
      );
      expect(
        approved.spokenLine(item, time: '10:30', approvedOnly: true),
        isNotNull,
      );
    });

    test('an item whose activity left the catalog says nothing', () {
      final c = catalog();
      const gone = RoutineItem(
        itemId: 'i1',
        routineId: 'r1',
        catalogId: 'retired_activity',
        label: 'Old one',
        icon: 'star',
        time: '08:00',
        durationMin: 5,
      );
      expect(c.spokenLine(gone, time: '8:00', approvedOnly: false), isNull);
    });

    test('spoken times use a 12-hour clock', () {
      expect(spokenTime('00:05'), '12:05');
      expect(spokenTime('09:30'), '9:30');
      expect(spokenTime('12:00'), '12:00');
      expect(spokenTime('13:05'), '1:05');
      expect(spokenTime('22:30'), '10:30');
    });
  });

  group('limited activity (FR-GOL-03)', () {
    test('movement items start switched off and ask to check first', () {
      final c = catalog();
      final walk = c.byId('morning_walk')!;
      expect(c.needsClinicianCheck(walk, activityLimited: true), isTrue);
      final item = c.newItem(
        walk,
        itemId: 'i1',
        routineId: 'r1',
        activityLimited: true,
      );
      expect(item.reminder, isFalse);
      expect(item.avatarAnnounce, isFalse);
      expect(item.catalogId, 'morning_walk');
      expect(item.isValid, isTrue);
    });

    test('other items, and people not limited, keep their reminders', () {
      final c = catalog();
      final water = c.byId('drink_water')!;
      final walk = c.byId('morning_walk')!;
      expect(c.needsClinicianCheck(water, activityLimited: true), isFalse);
      expect(
        c
            .newItem(
              water,
              itemId: 'i1',
              routineId: 'r1',
              activityLimited: true,
            )
            .reminder,
        isTrue,
      );
      for (final answer in [false, null]) {
        expect(c.needsClinicianCheck(walk, activityLimited: answer), isFalse);
        expect(
          c
              .newItem(
                walk,
                itemId: 'i1',
                routineId: 'r1',
                activityLimited: answer,
              )
              .reminder,
          isTrue,
        );
      }
    });

    test('every catalog item makes a valid routine item', () {
      final c = catalog();
      for (final a in c.activities) {
        expect(
          c
              .newItem(a, itemId: 'i1', routineId: 'r1', activityLimited: null)
              .isValid,
          isTrue,
          reason: a.id,
        );
      }
    });
  });
}
