import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/routine/domain/label_check.dart';
import 'package:livewell/features/safety/domain/safety_rules.dart';

/// T-GOL-03c: custom routine labels. The shared case set
/// (packages/safety-rules/label_cases.json) must give the same answers here
/// as in the reference runner (check_label_cases.py).

const package = '../../packages/safety-rules';

LabelRules labels() => LabelRules.fromJson(
  jsonDecode(File('$package/label_rules.json').readAsStringSync())
      as Map<String, dynamic>,
);

SafetyRules shared() => SafetyRules.fromJson(
  jsonDecode(File('$package/rules.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('the app copy matches packages/safety-rules/label_rules.json', () {
    expect(
      File('assets/safety/label_rules.json').readAsStringSync(),
      File('$package/label_rules.json').readAsStringSync(),
    );
  });

  test('every shared label case gives the expected kind', () {
    final rules = labels();
    final cases =
        (jsonDecode(File('$package/label_cases.json').readAsStringSync())
                as Map<String, dynamic>)['cases']
            as List;
    expect(cases.length, greaterThanOrEqualTo(60));
    for (final c in cases.cast<Map<String, dynamic>>()) {
      expect(
        rules.check(c['text'] as String)?.key,
        c['expected'],
        reason: c['text'] as String,
      );
    }
  });

  group('the order of checks', () {
    test('red flags first: a crisis label gets the crisis response', () {
      final v = checkLabel('I want to die', shared(), labels());
      expect(v, isA<LabelRedFlag>());
      expect((v as LabelRedFlag).result.category, SafetyCategory.crisis);
    });

    test('short eating-disorder labels get the disordered-eating card', () {
      for (final label in ['Skip dinner', 'Purge', 'Eat 500 calories']) {
        final v = checkLabel(label, shared(), labels());
        expect(v, isA<LabelRedFlag>(), reason: label);
        expect(
          (v as LabelRedFlag).result.category,
          SafetyCategory.disorderedEating,
        );
        expect(v.result.interrupts, isFalse);
      }
    });

    test('a medication change is a red flag; a pill reminder is blocked', () {
      final change = checkLabel('Stop taking metformin', shared(), labels());
      expect(
        (change as LabelRedFlag).result.category,
        SafetyCategory.medication,
      );
      final reminder = checkLabel('Take my pills', shared(), labels());
      expect((reminder as LabelBlocked).kind, LabelKind.medication);
    });

    test('weight and diet goals, and unkind words, are blocked kindly', () {
      expect(
        (checkLabel('Weigh myself', shared(), labels()) as LabelBlocked).kind,
        LabelKind.notAllowed,
      );
      expect(
        (checkLabel('No excuses', shared(), labels()) as LabelBlocked).kind,
        LabelKind.unkind,
      );
    });

    test('everyday steps are fine', () {
      for (final label in [
        'Call mom',
        'Family dinner',
        'Fast walk',
        'Lift weights',
        'Breakfast with kids',
      ]) {
        expect(
          checkLabel(label, shared(), labels()),
          isA<LabelOk>(),
          reason: label,
        );
      }
    });

    test('an eating-disorder sign wins over a weaker kind', () {
      // "diet pills": both medication-like and a purging sign.
      final v = checkLabel('Diet pills', shared(), labels());
      expect(
        (v as LabelRedFlag).result.category,
        SafetyCategory.disorderedEating,
      );
    });
  });
}
