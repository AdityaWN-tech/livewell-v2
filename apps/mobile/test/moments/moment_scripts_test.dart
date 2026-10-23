import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/moments/domain/coach_message.dart';
import 'package:livewell/features/moments/domain/moment_builder.dart';
import 'package:livewell/features/moments/domain/moment_templates.dart';
import 'package:livewell/features/safety/domain/safety_rules.dart';

/// T-DLY-03a: the Avatar Moment scripts and the builder.

final contentDir = Directory('../../content/coach/moments');

List<MomentTemplate> templates() => [
  for (final m in Moment.values)
    MomentTemplate.parse(
      File('${contentDir.path}/${m.file}.json').readAsStringSync(),
    ),
];

MomentBuilder builder({bool approvedOnly = false}) =>
    MomentBuilder(templates(), approvedOnly: approvedOnly);

const walk = MomentStep(
  title: '10-min walk after lunch',
  minutes: 10,
  smallerTitle: '5-min walk after lunch',
  smallerMinutes: 5,
);

/// Wednesday 2026-10-14 at 7:00.
MomentContext full({DateTime? now}) => MomentContext(
  now: now ?? DateTime(2026, 10, 14, 7),
  firstName: 'Priya',
  why: 'Energy to travel with my family.',
  step: walk,
  streakDays: 9,
  weeklyCount: 5,
);

/// Rough Flesch-Kincaid grade, enough to keep lines near 8th grade.
double grade(String text) {
  final sentences = RegExp(r'[.!?]+').allMatches(text).length.clamp(1, 99);
  final words = text
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r"[^A-Za-z']"), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  int syllables(String w) {
    final s = w.toLowerCase().replaceAll(RegExp(r"e$|'"), '');
    final n = RegExp(r'[aeiouy]+').allMatches(s).length;
    return n < 1 ? 1 : n;
  }

  final syl = words.fold<int>(0, (a, w) => a + syllables(w));
  return 0.39 * words.length / sentences + 11.8 * syl / words.length - 15.59;
}

void main() {
  group('the script files (content/coach/moments)', () {
    test('the app copy matches content/coach/moments', () {
      for (final m in Moment.values) {
        expect(
          File('assets/coach/moments/${m.file}.json').readAsStringSync(),
          File('${contentDir.path}/${m.file}.json').readAsStringSync(),
          reason: m.file,
        );
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/coach/moments/'),
      );
    });

    test('every moment, several variants each, all pending review', () {
      final all = templates();
      expect(all.map((t) => t.moment).toSet(), Moment.values.toSet());
      for (final t in all) {
        expect(
          t.variants.length,
          greaterThanOrEqualTo(3),
          reason: '${t.moment}',
        );
        expect(t.approved, isFalse, reason: 'pending until clinical review');
        final ids = t.variants.map((v) => v.id).toList();
        expect(ids.toSet().length, ids.length, reason: '${t.moment}');
      }
    });

    test('only the safe placeholders are allowed', () {
      for (final t in templates()) {
        for (final v in t.variants) {
          expect(
            v.placeholders.difference(MomentPlaceholders.all),
            isEmpty,
            reason: v.id,
          );
        }
      }
      expect(
        () => MomentTemplate.parse(
          jsonEncode({
            'version': 1,
            'moment': 'morning',
            'review_status': 'pending',
            'emotion': 'waving',
            'primary_action': 'check_in',
            'secondary_actions': <String>[],
            'variants': [
              {'id': 'bad', 'text': 'Your mood was {mood} today.'},
            ],
          }),
        ),
        throwsFormatException,
        reason: 'health values never go into a script',
      );
    });

    test('every line is listed in REVIEW.md for clinical review', () {
      final review = File('${contentDir.path}/REVIEW.md').readAsStringSync();
      for (final t in templates()) {
        for (final v in t.variants) {
          expect(review, contains('`${t.moment.file}.${v.id}`'));
          expect(review, contains(v.text));
        }
      }
    });

    test('invitations, never orders or guilt; about an 8th-grade level', () {
      final banned = RegExp(
        r"\b(must|should|have to|need to|failed?|lazy|disappoint\w*|"
        r"behind|no excuses?|why didn't)\b",
        caseSensitive: false,
      );
      for (final t in templates()) {
        for (final v in t.variants) {
          final filled = builderFill(v.text);
          expect(banned.hasMatch(v.text), isFalse, reason: v.id);
          expect(grade(filled), lessThanOrEqualTo(8.5), reason: v.id);
        }
      }
    });

    test('no intense exercise, no portal or course mentions', () {
      final intense = RegExp(
        r'\b(run|running|jog\w*|sprint\w*|hiit|intense|workout|burn)\b',
        caseSensitive: false,
      );
      final portal = RegExp(
        r'\b(portal|course|buy|price|subscribe|offer)\b',
        caseSensitive: false,
      );
      for (final t in templates()) {
        for (final v in t.variants) {
          expect(intense.hasMatch(v.text), isFalse, reason: v.id);
          expect(portal.hasMatch(v.text), isFalse, reason: v.id);
        }
      }
    });

    test('no line trips the red-flag rules (FR-SAF-01/02)', () {
      final rules = SafetyRules.fromJson(
        jsonDecode(
          File('../../packages/safety-rules/rules.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      for (final t in templates()) {
        for (final v in t.variants) {
          expect(
            rules.check(builderFill(v.text)).isClear,
            isTrue,
            reason: v.id,
          );
        }
      }
    });
  });

  group('the builder', () {
    test('every moment renders with all its data filled in', () {
      for (final m in Moment.values) {
        final msg = builder().build(m, full())!;
        expect(msg.text, isNot(contains('{')), reason: m.file);
        expect(msg.text, isNot(contains('}')), reason: m.file);
        expect(msg.messageId, matches(RegExp('^${m.file}\\.[a-z]\\d@v1\$')));
        expect(msg.approved, isFalse);
      }
    });

    test('expression and buttons come from the moment', () {
      final b = builder();
      expect(b.build(Moment.morning, full())!.emotion, CoachEmotion.waving);
      expect(
        b.build(Moment.stepReminder, full())!.emotion,
        CoachEmotion.encouraging,
      );
      expect(
        b.build(Moment.stepDone, full())!.emotion,
        CoachEmotion.celebrating,
      );
      expect(b.build(Moment.evening, full())!.emotion, CoachEmotion.listening);
      expect(b.build(Moment.gentle, full())!.emotion, CoachEmotion.calm);
      final morning = b.build(Moment.morning, full())!;
      expect(morning.primaryAction, MomentAction.checkIn);
      expect(morning.secondaryActions, [
        MomentAction.startStep,
        MomentAction.makeSmaller,
      ]);
      expect(
        b.build(Moment.stepReminder, full())!.secondaryActions,
        contains(MomentAction.notToday),
      );
    });

    test('a different line each day: never the same two days in a row', () {
      for (final m in Moment.values) {
        String? yesterday;
        for (var d = 0; d < 30; d++) {
          final id = builder()
              .build(m, full(now: DateTime(2026, 10, 1 + d, 7)))!
              .messageId;
          expect(id, isNot(yesterday), reason: '${m.file} day $d');
          yesterday = id;
        }
      }
    });

    test('personal lines when the name and step are known', () {
      for (var d = 0; d < 14; d++) {
        final msg = builder().build(
          Moment.morning,
          full(now: DateTime(2026, 10, 1 + d, 7)),
        )!;
        expect(msg.text, contains('Priya'), reason: msg.messageId);
        expect(msg.text, contains('walk after lunch'), reason: msg.messageId);
        expect(msg.containsUserText, isTrue);
      }
    });

    test('missing data: only lines without it, never a gap', () {
      final bare = MomentContext(now: DateTime(2026, 10, 14, 7));
      for (final m in [
        Moment.morning,
        Moment.stepDone,
        Moment.evening,
        Moment.gentle,
        Moment.missedDay,
        Moment.weeklyReview,
      ]) {
        final msg = builder().build(m, bare)!;
        expect(msg.text, isNot(contains('{')), reason: m.file);
        expect(msg.text, isNot(contains('null')), reason: m.file);
        expect(msg.containsUserText, isFalse, reason: m.file);
      }
      // No plan, no step reminder.
      expect(builder().build(Moment.stepReminder, bare), isNull);
      // A step with no smaller version: no "Short on time? X minutes".
      final noSmaller = MomentContext(
        now: DateTime(2026, 10, 14, 7),
        firstName: 'Priya',
        step: const MomentStep(title: 'A slow, easy walk', minutes: 5),
      );
      for (var d = 0; d < 7; d++) {
        final msg = builder().build(
          Moment.morning,
          MomentContext(
            now: DateTime(2026, 10, 1 + d, 7),
            firstName: noSmaller.firstName,
            step: noSmaller.step,
          ),
        )!;
        expect(msg.text, isNot(contains('Short on time')));
      }
    });

    test('gentle day: always the smaller step and its minutes', () {
      for (var d = 0; d < 7; d++) {
        final msg = builder().build(
          Moment.gentle,
          full(now: DateTime(2026, 10, 1 + d, 9)),
        )!;
        expect(msg.text, isNot(contains('10-min')), reason: msg.messageId);
      }
      expect(
        MomentBuilder.afterCheckIn(gentleDay: true, mood: 5),
        Moment.gentle,
      );
    });

    test('missed day: restart wording, never shaming', () {
      expect(MomentBuilder.morningFor(missedYesterday: true), Moment.missedDay);
      expect(MomentBuilder.morningFor(missedYesterday: false), Moment.morning);
      final msg = builder().build(Moment.missedDay, full())!;
      expect(msg.text, contains('rest day'));
      expect(msg.primaryAction, MomentAction.restart);
    });

    test('safety hold: no Avatar Moment at all (safety cards instead)', () {
      final held = MomentContext(
        now: DateTime(2026, 10, 14, 7),
        firstName: 'Priya',
        step: walk,
        safetyHold: true,
      );
      for (final m in Moment.values) {
        expect(builder().build(m, held), isNull, reason: m.file);
      }
    });

    test('prod: approved scripts only (all are pending today)', () {
      for (final m in Moment.values) {
        expect(builder(approvedOnly: true).build(m, full()), isNull);
      }
    });

    test('the Why reads as part of the sentence', () {
      String whyLine(String why) {
        for (var d = 0; d < 14; d++) {
          final msg = builder().build(
            Moment.morning,
            MomentContext(
              now: DateTime(2026, 10, 1 + d, 7),
              firstName: 'Priya',
              why: why,
              step: walk,
            ),
          )!;
          if (msg.text.contains('reason') || msg.text.contains('why:')) {
            return msg.text;
          }
        }
        fail('no line with the Why');
      }

      expect(whyLine('Energy to travel.'), contains(': energy to travel.'));
      expect(whyLine('I want to keep up with my kids'), contains(': I want'));
      expect(whyLine('Energy!'), isNot(contains('!.')));
    });

    test('time of day follows the clock', () {
      expect(MomentBuilder.timeOfDay(DateTime(2026, 10, 14, 7)), 'morning');
      expect(MomentBuilder.timeOfDay(DateTime(2026, 10, 14, 13)), 'afternoon');
      expect(MomentBuilder.timeOfDay(DateTime(2026, 10, 14, 20)), 'evening');
      expect(MomentBuilder.timeOfDay(DateTime(2026, 10, 14, 2)), 'evening');
    });
  });
}

/// A line with sample values, for the reading-level and safety checks.
String builderFill(String text) => text.replaceAllMapped(
  MomentPlaceholders.pattern,
  (m) => switch (m[1]) {
    'first_name' => 'Priya',
    'why' => 'Energy to travel with my family',
    'step_title' => 'a walk after lunch',
    'time_of_day' => 'morning',
    _ => '5',
  },
);
