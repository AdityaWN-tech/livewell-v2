/// Measures the person records on Track (T-GOL-02, FR-GOL-04, D-72):
/// weight, blood pressure, glucose and meals. Every point keeps where it
/// came from and when it was measured (Blueprint 10.3), and both are shown
/// next to it.
///
/// The app only records these values. It never says whether a value is
/// good, bad, high, low or normal, and gives no advice about them (spec
/// 9.4: no diagnostic interpretation of metrics; D-72).
library;

/// What a point measures. The names are the stored `kind` values.
enum MetricKind {
  weight('weight'),
  bloodPressure('blood_pressure'),
  glucose('glucose'),
  meal('meal');

  const MetricKind(this.id);
  final String id;

  static MetricKind? fromId(String? id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Weight and meals are hidden in the eating-safe mode (FR-SAF-04, D-72).
  bool get hiddenInEdSafeMode =>
      this == MetricKind.weight || this == MetricKind.meal;
}

/// Where a point came from: typed in by the person, or read from Apple
/// Health / Health Connect.
enum MetricSource {
  manual('manual'),
  health('health');

  const MetricSource(this.id);
  final String id;

  static MetricSource fromId(String? id) => id == health.id ? health : manual;
}

/// Weight units. Blood pressure is always mmHg and glucose mg/dL, the
/// units used in both markets (India and US, D-03).
enum WeightUnit {
  kg('kg', 20, 300),
  lb('lb', 44, 660);

  const WeightUnit(this.id, this.min, this.max);
  final String id;

  /// The accepted range (D-72): wide on purpose, it only catches typos.
  final double min;
  final double max;

  static WeightUnit? fromId(String? id) => switch (id) {
    'kg' => kg,
    'lb' => lb,
    _ => null,
  };

  /// The starting unit for a region (NFR-11: units follow locale): pounds
  /// in the US, kilograms elsewhere. The person can switch on every entry.
  static WeightUnit forRegion(String? region) => region == 'US' ? lb : kg;

  static const lbPerKg = 2.20462;

  double convert(double value, WeightUnit to) {
    if (to == this) return value;
    return this == kg ? value * lbPerKg : value / lbPerKg;
  }
}

/// Fixed limits, the same as firestore.rules (D-72). They catch typos; a
/// value inside them is recorded as it is, with no comment.
abstract final class MetricLimits {
  static const systolicMin = 50;
  static const systolicMax = 260;
  static const diastolicMin = 30;
  static const diastolicMax = 160;
  static const bpUnit = 'mmHg';
  static const glucoseMin = 20;
  static const glucoseMax = 600;
  static const glucoseUnit = 'mg/dL';

  /// A point can be dated up to this far back.
  static const maxBackdate = Duration(days: 30);
}

enum MealKind { breakfast, lunch, dinner, snack }

/// One recorded measure (users/{uid}/metrics/{id}).
class MetricPoint {
  const MetricPoint({
    required this.id,
    required this.kind,
    required this.measuredAt,
    this.source = MetricSource.manual,
    this.value,
    this.weightUnit,
    this.systolic,
    this.diastolic,
    this.meal,
  });

  const MetricPoint.weight({
    required this.id,
    required double kgOrLb,
    required WeightUnit unit,
    required this.measuredAt,
    this.source = MetricSource.manual,
  }) : kind = MetricKind.weight,
       value = kgOrLb,
       weightUnit = unit,
       systolic = null,
       diastolic = null,
       meal = null;

  const MetricPoint.bloodPressure({
    required this.id,
    required int this.systolic,
    required int this.diastolic,
    required this.measuredAt,
    this.source = MetricSource.manual,
  }) : kind = MetricKind.bloodPressure,
       value = null,
       weightUnit = null,
       meal = null;

  const MetricPoint.glucose({
    required this.id,
    required int mgDl,
    required this.measuredAt,
    this.source = MetricSource.manual,
  }) : kind = MetricKind.glucose,
       value = mgDl + 0.0,
       weightUnit = null,
       systolic = null,
       diastolic = null,
       meal = null;

  const MetricPoint.meal({
    required this.id,
    required MealKind this.meal,
    required this.measuredAt,
    this.source = MetricSource.manual,
  }) : kind = MetricKind.meal,
       value = null,
       weightUnit = null,
       systolic = null,
       diastolic = null;

  final String id;
  final MetricKind kind;
  final MetricSource source;

  /// When it was measured (or eaten), local time.
  final DateTime measuredAt;

  /// Weight (in [weightUnit]) or glucose (mg/dL).
  final double? value;
  final WeightUnit? weightUnit;
  final int? systolic;
  final int? diastolic;
  final MealKind? meal;

  /// The stored unit, as written in the document.
  String? get unit => switch (kind) {
    MetricKind.weight => weightUnit?.id,
    MetricKind.bloodPressure => MetricLimits.bpUnit,
    MetricKind.glucose => MetricLimits.glucoseUnit,
    MetricKind.meal => null,
  };

  /// Whether the values are inside the limits (the rules check the same).
  bool isValidAt(DateTime now) {
    if (measuredAt.isAfter(now.add(const Duration(minutes: 10)))) return false;
    if (measuredAt.isBefore(now.subtract(MetricLimits.maxBackdate))) {
      return false;
    }
    return switch (kind) {
      MetricKind.weight =>
        value != null &&
            weightUnit != null &&
            value! >= weightUnit!.min &&
            value! <= weightUnit!.max,
      MetricKind.bloodPressure =>
        systolic != null &&
            diastolic != null &&
            systolic! >= MetricLimits.systolicMin &&
            systolic! <= MetricLimits.systolicMax &&
            diastolic! >= MetricLimits.diastolicMin &&
            diastolic! <= MetricLimits.diastolicMax &&
            systolic! > diastolic!,
      MetricKind.glucose =>
        value != null &&
            value! == value!.roundToDouble() &&
            value! >= MetricLimits.glucoseMin &&
            value! <= MetricLimits.glucoseMax,
      MetricKind.meal => meal != null,
    };
  }

  /// The fields stored besides kind, source, measured_at and the meta.
  Map<String, Object> valueFields() => switch (kind) {
    MetricKind.weight => {'value': value!, 'unit': weightUnit!.id},
    MetricKind.bloodPressure => {
      'systolic': systolic!,
      'diastolic': diastolic!,
      'unit': MetricLimits.bpUnit,
    },
    MetricKind.glucose => {
      'value': value!.round(),
      'unit': MetricLimits.glucoseUnit,
    },
    MetricKind.meal => {'meal': meal!.name},
  };

  /// Reads a stored document; null for anything it doesn't understand.
  static MetricPoint? fromData(
    String id,
    Map<String, dynamic> d,
    DateTime measuredAt,
  ) {
    final source = MetricSource.fromId(d['source'] as String?);
    switch (MetricKind.fromId(d['kind'] as String?)) {
      case MetricKind.weight:
        final unit = WeightUnit.fromId(d['unit'] as String?);
        final v = (d['value'] as num?)?.toDouble();
        if (unit == null || v == null) return null;
        return MetricPoint.weight(
          id: id,
          kgOrLb: v,
          unit: unit,
          measuredAt: measuredAt,
          source: source,
        );
      case MetricKind.bloodPressure:
        final s = (d['systolic'] as num?)?.toInt();
        final di = (d['diastolic'] as num?)?.toInt();
        if (s == null || di == null) return null;
        return MetricPoint.bloodPressure(
          id: id,
          systolic: s,
          diastolic: di,
          measuredAt: measuredAt,
          source: source,
        );
      case MetricKind.glucose:
        final v = (d['value'] as num?)?.toInt();
        if (v == null) return null;
        return MetricPoint.glucose(
          id: id,
          mgDl: v,
          measuredAt: measuredAt,
          source: source,
        );
      case MetricKind.meal:
        final m = MealKind.values.where((m) => m.name == d['meal']);
        if (m.isEmpty) return null;
        return MetricPoint.meal(
          id: id,
          meal: m.first,
          measuredAt: measuredAt,
          source: source,
        );
      case null:
        return null;
    }
  }
}

/// Reads a typed number, accepting a comma as the decimal mark.
double? parseMeasure(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
