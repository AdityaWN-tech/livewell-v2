import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/safety/data/safety_rules_provider.dart';
import 'package:livewell/features/safety/domain/safety_rules.dart';

/// T-ASM-02 done-when: all red-flag rule tests pass. The cases are shared
/// with the reference engine (packages/safety-rules/check_cases.py) and the
/// future agents service. Critical cases must be 100% (spec 15.2).
void main() {
  final rulesFile = File('../../packages/safety-rules/rules.json');
  final rules = SafetyRules.fromJson(
    jsonDecode(rulesFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final cases =
      ((jsonDecode(
                File('../../packages/safety-rules/cases.json')
                    .readAsStringSync(),
              ) as Map)['cases']
              as List)
          .cast<Map<String, dynamic>>();

  test('the bundled rules are an exact copy of packages/safety-rules', () {
    expect(
      File(safetyRulesAsset).readAsStringSync(),
      rulesFile.readAsStringSync(),
    );
  });

  test('every rule id is unique and every pattern compiles', () {
    final ids = rules.rules.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final c in SafetyCategory.values) {
      expect(rules.rules.any((r) => r.category == c), isTrue, reason: c.key);
    }
  });

  group('critical cases (must be 100%)', () {
    for (final c in cases.where((c) => c['critical'] == true)) {
      test(c['text'], () {
        expect(rules.check(c['text'] as String).category?.key, c['expected']);
      });
    }
  });

  group('other cases', () {
    for (final c in cases.where((c) => c['critical'] != true)) {
      test(c['text'], () {
        expect(rules.check(c['text'] as String).category?.key, c['expected']);
      });
    }
  });

  test('every spec 15.3 input case is in the set', () {
    final fromSpec = cases.where((c) => c['source'] == 'spec 15.3').length;
    expect(fromSpec, greaterThanOrEqualTo(7));
  });

  test('emergency outranks crisis, and both rule ids are kept for the log', () {
    final r = rules.check('I took too many pills because I want to die');
    expect(r.category, SafetyCategory.emergency);
    expect(r.ruleIds, containsAll(['EM-OVERDOSE', 'CR-SUICIDE']));
    expect(r.interrupts, isTrue);
  });

  test('only emergency and crisis interrupt', () {
    expect(SafetyCategory.values.where((c) => c.interrupts), [
      SafetyCategory.emergency,
      SafetyCategory.crisis,
    ]);
  });

  test('empty or punctuation-only text is clear', () {
    expect(rules.check('').isClear, isTrue);
    expect(rules.check('  ?!  ').isClear, isTrue);
  });

  group('region numbers (D-03: never guessed)', () {
    test('US: 911 and 988 (call or text)', () {
      final us = rules.contactsFor('US').single;
      expect(us.emergency, '911');
      expect(us.crisisCall, '988');
      expect(us.crisisText, '988');
    });
    test('India: 112 and Tele-MANAS 14416', () {
      final india = rules.contactsFor('IN').single;
      expect(india.emergency, '112');
      expect(india.crisisCall, '14416');
      expect(india.crisisName, 'Tele-MANAS');
    });
    test('unknown region shows both', () {
      expect(rules.contactsFor(null).map((c) => c.region), ['US', 'IN']);
      expect(rules.contactsFor('GB').map((c) => c.region), ['US', 'IN']);
    });
  });
}
