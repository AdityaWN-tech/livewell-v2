import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/avatar/domain/avatar_options.dart';

/// Step 1 (FR-AVT-02): the option lists for Build my own and Adjust.

final content = File('../../content/avatar/options.json');
AvatarOptions options() => AvatarOptions.parse(content.readAsStringSync());

Set<String> ids(String category) => {
  for (final o in options()[category]!.options) o.id,
};

void main() {
  test('the app copy matches content/avatar/options.json', () {
    expect(
      File('assets/avatar/options.json').readAsStringSync(),
      content.readAsStringSync(),
    );
  });

  test('FR-AVT-02: an inclusive set (spec 7.2 minimums)', () {
    expect(ids('skin').length, greaterThanOrEqualTo(8));
    expect(ids('hairstyle').length, greaterThanOrEqualTo(20));
    expect(ids('body_type').length, greaterThanOrEqualTo(6));
    // Adults only: an age range from the 20s to the 70s.
    expect(ids('age_range'), {'20s', '30s', '40s', '50s', '60s', '70s'});
    expect(ids('glasses'), containsAll(['round', 'rectangular', 'reading']));
    expect(ids('head_covering'), containsAll(['hijab', 'turban', 'kippah']));
    // Mobility aids and hearing aids.
    expect(ids('accessories'), containsAll(['wheelchair', 'hearing_aid']));
  });

  test('every option has a label to show', () {
    for (final c in options().categories) {
      expect(c.options, isNotEmpty, reason: c.id);
      for (final o in c.options) {
        expect(o.label.trim(), isNotEmpty, reason: '${c.id}.${o.id}');
      }
    }
  });

  test('Adjust changes the look, never who the coach is', () {
    final adjust = {for (final c in options().forAdjust) c.id};
    expect(adjust, {
      'hairstyle',
      'hair_colour',
      'outfit',
      'outfit_colour',
      'cap',
      'head_covering',
      'glasses',
      'accessories',
    });
    for (final kept in ['face', 'skin', 'age_range', 'body_type', 'eyes']) {
      expect(adjust, isNot(contains(kept)));
    }
  });

  test('a complete default choice, and nothing outside the lists is sent', () {
    final o = options();
    final d = o.defaults;
    expect(d.keys.toSet(), {for (final c in o.categories) c.id});
    expect(o.valid(d), d);
    expect(
      o.valid({
        ...d,
        'outfit': 'superhero_costume',
        'notes': 'make me younger',
      }),
      {
        for (final e in d.entries)
          if (e.key != 'outfit') e.key: e.value,
      },
    );
  });
}
