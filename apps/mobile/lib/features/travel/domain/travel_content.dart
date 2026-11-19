import 'dart:convert';

/// Basic Travel Mode content (FR-TRV-02, D-86): a copy of
/// content/travel/travel.json, checked by a test. Prod and staging use it
/// only once the clinical team approves it (review_status: approved); the
/// dev build may use pending content.
class TravelContent {
  const TravelContent({
    required this.version,
    required this.approved,
    required this.stepLabel,
    required this.pillars,
    required this.jetLag,
    required this.microhabits,
  });

  final int version;

  /// The clinical team approved it (review_status: approved).
  final bool approved;

  /// Shown with a travel step on Home and Plan, e.g. "Travel Mode".
  final String stepLabel;
  final List<TravelPillar> pillars;
  final List<JetLagTip> jetLag;
  final List<TravelMicrohabit> microhabits;

  /// The four pillars, in this order (Blueprint 6.10).
  static const pillarIds = [
    'eat_well',
    'move_well',
    'sleep_recover',
    'breathe_reset',
  ];

  static TravelContent parse(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return TravelContent(
      version: m['version'] as int,
      approved: m['review_status'] == 'approved',
      stepLabel: m['step_label'] as String,
      pillars: [
        for (final p in m['pillars'] as List)
          TravelPillar.fromJson(p as Map<String, dynamic>),
      ],
      jetLag: [
        for (final j in m['jet_lag'] as List)
          JetLagTip.fromJson(j as Map<String, dynamic>),
      ],
      microhabits: [
        for (final h in m['microhabits'] as List)
          TravelMicrohabit.fromJson(h as Map<String, dynamic>),
      ],
    );
  }

  /// Usable in this build: always in dev, otherwise only once approved.
  bool usable({required bool isDev}) => isDev || approved;

  TravelPillar? pillar(String id) =>
      pillars.where((p) => p.id == id).firstOrNull;

  JetLagTip? tipFor(JetLagDirection direction) =>
      jetLag.where((t) => t.direction == direction).firstOrNull;

  /// Today's travel microhabit: one per day of the trip, in turn, starting
  /// with the first on the trip's first day. Movement steps are left out
  /// for people who said an activity limits them (FR-GOL-03).
  TravelMicrohabit? stepFor({
    required int tripDay,
    required bool activityLimited,
  }) {
    final choices = [
      for (final h in microhabits)
        if (!(activityLimited && h.movement)) h,
    ];
    if (choices.isEmpty) return null;
    final i = tripDay < 0 ? 0 : tripDay;
    return choices[i % choices.length];
  }
}

/// One of the four travel pillars.
class TravelPillar {
  const TravelPillar({
    required this.id,
    required this.title,
    required this.intro,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final String intro;
  final String icon;
  final List<TravelItem> items;

  factory TravelPillar.fromJson(Map<String, dynamic> m) => TravelPillar(
    id: m['id'] as String,
    title: m['title'] as String,
    intro: m['intro'] as String,
    icon: m['icon'] as String,
    items: [
      for (final i in m['items'] as List)
        TravelItem.fromJson(i as Map<String, dynamic>),
    ],
  );
}

/// A routine or tip inside a pillar (hotel-room routine, jet-lag tip...).
class TravelItem {
  const TravelItem({
    required this.id,
    required this.title,
    required this.body,
    required this.minutes,
    required this.movement,
  });

  final String id;
  final String title;
  final String body;
  final int minutes;

  /// Physical activity: shows "Check with your clinician first" for people
  /// whose activity is limited (FR-GOL-03).
  final bool movement;

  factory TravelItem.fromJson(Map<String, dynamic> m) => TravelItem(
    id: m['id'] as String,
    title: m['title'] as String,
    body: m['body'] as String,
    minutes: m['minutes'] as int,
    movement: m['movement'] as bool,
  );
}

/// Which way the trip moves the clock.
enum JetLagDirection {
  /// Less than [JetLag.smallHours] hours of difference.
  small,

  /// The destination is ahead of home.
  east,

  /// The destination is behind home.
  west;

  static JetLagDirection? byName(String? name) =>
      values.where((d) => d.name == name).firstOrNull;
}

abstract final class JetLag {
  /// Under this many hours the body adjusts quickly.
  static const smallHours = 3;

  /// The direction for a trip from a zone [home] offset to [destination].
  static JetLagDirection direction(Duration home, Duration destination) {
    final diff = destination - home;
    if (diff.inMinutes.abs() < smallHours * 60) return JetLagDirection.small;
    return diff.isNegative ? JetLagDirection.west : JetLagDirection.east;
  }
}

class JetLagTip {
  const JetLagTip({
    required this.id,
    required this.direction,
    required this.title,
    required this.body,
  });

  final String id;
  final JetLagDirection direction;
  final String title;
  final String body;

  factory JetLagTip.fromJson(Map<String, dynamic> m) => JetLagTip(
    id: m['id'] as String,
    direction: JetLagDirection.byName(m['direction'] as String?)!,
    title: m['title'] as String,
    body: m['body'] as String,
  );
}

/// A daily step while travelling (FR-TRV-01: the plan switches to travel
/// microhabits).
class TravelMicrohabit {
  const TravelMicrohabit({
    required this.id,
    required this.pillar,
    required this.title,
    required this.reason,
    required this.minutes,
    required this.movement,
    this.smallerTitle,
    this.smallerMinutes,
  });

  final String id;
  final String pillar;
  final String title;
  final String reason;
  final int minutes;
  final bool movement;
  final String? smallerTitle;
  final int? smallerMinutes;

  factory TravelMicrohabit.fromJson(Map<String, dynamic> m) => TravelMicrohabit(
    id: m['id'] as String,
    pillar: m['pillar'] as String,
    title: m['title'] as String,
    reason: m['reason'] as String,
    minutes: m['minutes'] as int,
    movement: m['movement'] as bool,
    smallerTitle: m['smaller_title'] as String?,
    smallerMinutes: m['smaller_minutes'] as int?,
  );
}
