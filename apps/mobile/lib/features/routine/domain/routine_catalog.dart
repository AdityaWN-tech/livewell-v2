import 'dart:convert';

import 'routine.dart';

/// The placeholders a routine line may use (T-GOL-03a). Anything else is
/// rejected when the catalog is read (tested).
abstract final class RoutinePlaceholders {
  static const firstName = 'first_name';

  /// The item's time, e.g. "9:30".
  static const time = 'time';

  static const all = {firstName, time};

  static Set<String> inText(String text) => {
    for (final m in RegExp(r'\{([a-z_]+)\}').allMatches(text)) m.group(1)!,
  };
}

/// One line the coach can say.
class RoutineLine {
  const RoutineLine({required this.id, required this.text});

  final String id;
  final String text;

  Set<String> get placeholders => RoutinePlaceholders.inText(text);
}

/// What kind of activity it is (for grouping in the picker).
enum ActivityKind { rest, nourish, move, mind, social, sleep }

/// One approved activity (content/routine/catalog.json).
class CatalogActivity {
  const CatalogActivity({
    required this.id,
    required this.label,
    required this.spokenName,
    required this.icon,
    required this.kind,
    required this.movement,
    required this.defaultTime,
    required this.defaultDurationMin,
    required this.lines,
  });

  final String id;
  final String label;
  final String spokenName;
  final String icon;
  final ActivityKind kind;

  /// Physical activity: off by default, with "Check with your clinician
  /// first", for people whose activity is limited (FR-GOL-03).
  final bool movement;
  final String defaultTime;
  final int defaultDurationMin;
  final List<RoutineLine> lines;
}

/// Which days a template is for.
enum TemplateDays {
  everyDay,
  weekdays,
  weekend,

  /// Just the day being edited (e.g. a travel day).
  oneDay;

  Set<Weekday> resolve(Weekday selected) => switch (this) {
    everyDay => Weekday.values.toSet(),
    weekdays => {
      Weekday.mon,
      Weekday.tue,
      Weekday.wed,
      Weekday.thu,
      Weekday.fri,
    },
    weekend => {Weekday.sat, Weekday.sun},
    oneDay => {selected},
  };
}

/// A quick-start template (content/routine/catalog.json): catalog
/// activities at set times. The person picks one and edits it.
class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.label,
    required this.days,
    required this.items,
  });

  final String id;
  final String label;
  final TemplateDays days;

  /// (catalog id, "HH:MM").
  final List<(String, String)> items;
}

/// The approved activity list and the coach's lines for routine items.
class RoutineCatalog {
  const RoutineCatalog({
    required this.version,
    required this.approved,
    required this.activities,
    required this.customLines,
    this.templates = const [],
  });

  final int version;

  /// The clinical team approved the lines (review_status: approved).
  final bool approved;
  final List<CatalogActivity> activities;

  /// General lines for custom items, which never say the custom label.
  final List<RoutineLine> customLines;

  /// Quick-start templates (Morning starter, Workday, Weekend, Travel day).
  final List<RoutineTemplate> templates;

  CatalogActivity? byId(String? id) =>
      activities.where((a) => a.id == id).firstOrNull;

  static RoutineCatalog parse(String json) {
    final d = jsonDecode(json) as Map<String, dynamic>;
    List<RoutineLine> lines(Object? list, String owner) => [
      for (final l in (list as List).cast<Map<String, dynamic>>())
        _checked(
          RoutineLine(id: l['id'] as String, text: l['text'] as String),
          owner,
        ),
    ];

    final activities = [
      for (final a in (d['activities'] as List).cast<Map<String, dynamic>>())
        CatalogActivity(
          id: a['id'] as String,
          label: a['label'] as String,
          spokenName: a['spoken_name'] as String,
          icon: _icon(a['icon'] as String),
          kind: ActivityKind.values.byName(a['kind'] as String),
          movement: a['movement'] as bool,
          defaultTime: _time(a['default_time'] as String),
          defaultDurationMin: a['default_duration_min'] as int,
          lines: lines(a['lines'], a['id'] as String),
        ),
    ];
    return RoutineCatalog(
      version: d['version'] as int,
      approved: d['review_status'] == 'approved',
      activities: activities,
      customLines: lines(d['custom_lines'], 'custom'),
      templates: [
        for (final t
            in (d['templates'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          RoutineTemplate(
            id: t['id'] as String,
            label: t['label'] as String,
            days: TemplateDays.values.byName(t['days'] as String),
            items: [
              for (final i in (t['items'] as List).cast<Map<String, dynamic>>())
                (
                  _known(i['catalog_id'] as String, activities),
                  _time(i['time'] as String),
                ),
            ],
          ),
      ],
    );
  }

  static RoutineLine _checked(RoutineLine l, String owner) {
    final unknown = l.placeholders.difference(RoutinePlaceholders.all);
    if (unknown.isNotEmpty) {
      throw FormatException('unknown placeholders $unknown in $owner.${l.id}');
    }
    return l;
  }

  static String _known(String id, List<CatalogActivity> activities) =>
      activities.any((a) => a.id == id)
      ? id
      : throw FormatException('template uses unknown activity $id');

  static String _icon(String icon) => routineIcons.contains(icon)
      ? icon
      : throw FormatException('unknown icon $icon');

  static String _time(String t) =>
      isValidTime(t) ? t : throw FormatException('bad time $t');

  /// Whether to show "Check with your clinician first" and start the item
  /// switched off (FR-GOL-03). Unknown answers are not treated as limited.
  bool needsClinicianCheck(
    CatalogActivity a, {
    required bool? activityLimited,
  }) => a.movement && activityLimited == true;

  /// A new routine item for [a] with its defaults. For someone whose
  /// activity is limited, a movement item starts with its reminder and the
  /// coach's announcement off, so nothing nudges them to move until they
  /// choose to.
  RoutineItem newItem(
    CatalogActivity a, {
    required String itemId,
    required String routineId,
    required bool? activityLimited,
    int order = 0,
    String? time,
  }) {
    final on = !needsClinicianCheck(a, activityLimited: activityLimited);
    return RoutineItem(
      itemId: itemId,
      routineId: routineId,
      catalogId: a.id,
      label: a.label,
      icon: a.icon,
      time: time ?? a.defaultTime,
      durationMin: a.defaultDurationMin,
      reminder: on,
      avatarAnnounce: on,
      order: order,
    );
  }

  /// What the coach says when it's time for [item], or null when there is
  /// no line it may use.
  ///
  /// Closed-script rule (FR-VOC-05): only lines from this catalog are ever
  /// returned. A custom item gets a general line; its label is never part
  /// of the text. Outside dev ([approvedOnly]), nothing is said until the
  /// clinical team approves the catalog. [pick] chooses among the usable
  /// lines (e.g. by day), so the coach doesn't repeat itself.
  String? spokenLine(
    RoutineItem item, {
    String? firstName,
    required String time,
    required bool approvedOnly,
    int pick = 0,
  }) => pickLine(
    item,
    firstName: firstName,
    time: time,
    approvedOnly: approvedOnly,
    pick: pick,
  )?.text;

  /// [spokenLine] with the id of the line it used ("drink_water.d1" or
  /// "custom.c1"), for the message_id the voice layer checks (FR-VOC-05).
  ({String id, String text, bool usedName})? pickLine(
    RoutineItem item, {
    String? firstName,
    required String time,
    required bool approvedOnly,
    int pick = 0,
  }) {
    if (approvedOnly && !approved) return null;
    final candidates = item.custom
        ? customLines
        : byId(item.catalogId)?.lines ?? const <RoutineLine>[];
    final values = {
      RoutinePlaceholders.time: time,
      if (firstName != null && firstName.trim().isNotEmpty)
        RoutinePlaceholders.firstName: firstName.trim(),
    };
    final usable = [
      for (final l in candidates)
        if (values.keys.toSet().containsAll(l.placeholders)) l,
    ];
    if (usable.isEmpty) return null;
    final line = usable[pick % usable.length];
    var text = line.text;
    for (final e in values.entries) {
      text = text.replaceAll('{${e.key}}', e.value);
    }
    return (
      id: '${item.custom ? 'custom' : item.catalogId}.${line.id}',
      text: text,
      usedName: line.placeholders.contains(RoutinePlaceholders.firstName),
    );
  }
}

/// "9:30" / "13:05" for a spoken line (24-hour times read badly, so this
/// is a 12-hour clock without am/pm; the morning/evening wording carries it).
String spokenTime(String hhmm) {
  final m = minutesOf(hhmm);
  final h = (m ~/ 60) % 12;
  return '${h == 0 ? 12 : h}:${(m % 60).toString().padLeft(2, '0')}';
}
